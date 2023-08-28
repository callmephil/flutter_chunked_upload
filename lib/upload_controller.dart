import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

extension DoubleExtensions on double {
  String toPercentageString() {
    return '${(this * 100).toStringAsFixed(1)}%';
  }
}

Future<Duration> resolve(Future<void> future) async {
  final stopwatch = Stopwatch()..start();
  await future;
  stopwatch.stop();
  return stopwatch.elapsed;
}

class UploadConfig {
  final Stream<List<int>> readStream;
  final String fileName;
  final int fileSize;
  final String endpoint;
  final Map<String, dynamic> headers;

  UploadConfig({
    required this.readStream,
    required this.fileName,
    required this.fileSize,
    required this.endpoint,
    this.headers = const {},
  });
}

enum UploadStatus { none, uploading, paused, canceled, completed, failed }

class UploadState {
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0);
  final ValueNotifier<UploadStatus> _statusNotifier =
      ValueNotifier<UploadStatus>(UploadStatus.none);
  final ValueNotifier<String> _remainingTimeNotifier =
      ValueNotifier<String>('');

  ValueListenable<double> get progress => _progressNotifier;
  ValueListenable<UploadStatus> get status => _statusNotifier;

  ValueListenable<String> get remainingTime => _remainingTimeNotifier;

  void reset() {
    _progressNotifier.value = 0;
    _statusNotifier.value = UploadStatus.none;
    _remainingTimeNotifier.value = '';
  }

  void computeProgress(int totalBytesUploaded, int fileSize) {
    double progress = totalBytesUploaded / fileSize;
    _progressNotifier.value = progress;
  }

  void updateStatus(UploadStatus status) {
    _statusNotifier.value = status;
  }

  void updateRemainingTime(Duration remainingTime) {
    _remainingTimeNotifier.value = '${remainingTime.inSeconds}s remaining';
  }
  // Add more functionality like calculating time for each chunk or holding the status of the upload
}

class UploadController extends ChangeNotifier {
  late final Dio _dio;
  CancelToken? _cancelToken;
  late final StreamSubscription<List<int>> _chunkStreamSubscription;
  late bool _isPaused;
  // final int _chunkSize = 1024 * 1024; // 1MB

  final UploadState uploadState;
  final UploadConfig config;

  UploadController({
    required this.uploadState,
    required this.config,
  }) {
    _cancelToken = CancelToken();
    _isPaused = false;
  }

  void _initializeDio(UploadConfig config) {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.endpoint,
        headers: config.headers,
      ),
    );
  }

  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      _chunkStreamSubscription.pause();
      uploadState.updateStatus(UploadStatus.paused);
    }
  }

  void resume() {
    if (_isPaused) {
      _isPaused = false;
      _chunkStreamSubscription.resume();
      uploadState.updateStatus(UploadStatus.uploading);
    }
  }

  void cancel() async {
    _cancelToken?.cancel();
    _chunkStreamSubscription.cancel();
    uploadState.reset();

    await Dio().post(
      '${config.endpoint}/cancel-upload',
      data: {'fileName': config.fileName},
    ).whenComplete(() => print('canceling'));
  }

  Future<void> uploadStreamWithProgress() async {
    _initializeDio(config);

    var chunkIndex = 0;
    var totalBytesUploaded = 0;

    final chunkStreamController = StreamController<List<int>>();
    _isPaused = false;

    uploadState.updateStatus(UploadStatus.uploading);

    _chunkStreamSubscription = config.readStream.listen(
      (chunk) async {
        _chunkStreamSubscription.pause();
        chunkStreamController.add(chunk);

        final elapsedTime = await resolve(
          _uploadChunk(chunk, config, chunkIndex, totalBytesUploaded),
        );

        final remainingChunks =
            config.fileSize ~/ chunk.length - chunkIndex - 1;
        final remainingTime = elapsedTime * remainingChunks;
        uploadState.updateRemainingTime(remainingTime);

        totalBytesUploaded += chunk.length;
        chunkIndex++;
        _chunkStreamSubscription.resume();
      },
      onDone: () async {
        await _finalizeUpload(config.fileName, chunkIndex);
        chunkStreamController.close();
        uploadState.updateStatus(UploadStatus.completed);
        uploadState.reset();

        // uploadState.updateRemainingTime(Duration.zero);
      },
    );
  }

  Future<void> _uploadChunk(List<int> chunk, UploadConfig config,
      int chunkIndex, int totalBytesUploaded) async {
    final mimeType = lookupMimeType(config.fileName);
    final mediaType = mimeType != null ? MediaType.parse(mimeType) : null;
    final formData = FormData.fromMap({
      "chunk": MultipartFile.fromBytes(
        chunk,
        contentType: mediaType,
        filename: '${config.fileName}-chunk-${chunkIndex + 1}',
      ),
      "fileName": config.fileName,
      "chunkIndex": chunkIndex,
    });

    try {
      // We ensure that our cancel token is the one we created for this post.
      _cancelToken = CancelToken();
      final response = await _dio.post(
        "/upload",
        data: formData,
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200) {
        totalBytesUploaded += chunk.length;
        uploadState.computeProgress(totalBytesUploaded, config.fileSize);
        debugPrint(
          "Uploaded chunk ${totalBytesUploaded / config.fileSize}",
        );
      } else {
        debugPrint(
          "Upload failed for chunk $chunkIndex: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Upload failed for chunk $chunkIndex : $e");
    }
  }

  Future<void> _finalizeUpload(String fileName, int totalChunks) async {
    try {
      await _dio.post(
        '/finalize-upload',
        data: {
          'fileName': fileName,
          'totalChunks': totalChunks,
        },
      );

      debugPrint('Upload finalized');
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
