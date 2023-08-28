import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class UploadController extends ChangeNotifier {
  static final Dio _dio = Dio();
  final ValueNotifier<double> sendProgress = ValueNotifier<double>(0);
  final ValueNotifier<String> remainingTime = ValueNotifier<String>('');

  final UploadManager _uploadManager = UploadManager();
  final ChunkUploader _chunkUploader;
  final TimeEstimator _timeEstimator = TimeEstimator();

  StreamSubscription<List<int>>? _chunkStreamSubscription;

  UploadController({required String endPoint})
      : _chunkUploader = ChunkUploader(endPoint, _dio);

  void pause() => _uploadManager.pause();
  void resume() => _uploadManager.resume();
  void cancel() => _uploadManager.cancel();

  Future<void> uploadStreamWithProgress(
      Stream<List<int>> readStream, String fileName, int fileSize) async {
    _uploadManager.reset();
    _timeEstimator.reset();

    _chunkStreamSubscription = readStream.listen((chunk) async {
      if (_uploadManager.isCancelled) {
        _chunkStreamSubscription?.cancel();
        return;
      }

      if (_uploadManager.isPaused) {
        _uploadManager.pauseStream(_chunkStreamSubscription);
        await _uploadManager.whenResumed();
        _uploadManager.resumeStream(_chunkStreamSubscription);
      }

      DateTime startTime = DateTime.now();
      await _chunkUploader.upload(
          chunk, fileName, fileSize, _uploadManager.chunkIndex, sendProgress);
      _uploadManager.incrementChunkIndex();
      _timeEstimator.update(chunk, fileSize, startTime, remainingTime);
    }, onDone: () async {
      if (!_uploadManager.isCancelled) {
        await _chunkUploader.finalizeUpload(
            fileName, _uploadManager.chunkIndex);
      }
    });
  }
}

class UploadManager {
  int chunkIndex = 0;
  bool _isPaused = false;
  bool _isCancelled = false;
  Completer<void>? _resumeCompleter;

  void pauseStream(StreamSubscription<List<int>>? streamSubscription) {
    streamSubscription?.pause();
  }

  void resumeStream(StreamSubscription<List<int>>? streamSubscription) {
    streamSubscription?.resume();
  }

  void pause() {
    if (!_isPaused) {
      _isPaused = true;
    }
  }

  void resume() {
    if (_isPaused) {
      _isPaused = false;
      _resumeCompleter?.complete();
      _resumeCompleter = null;
    }
  }

  void cancel() {
    _isCancelled = true;
    resume();
  }

  void reset() {
    chunkIndex = 0;
    _isPaused = false;
    _isCancelled = false;
  }

  bool get isPaused => _isPaused;
  bool get isCancelled => _isCancelled;

  Future<void> whenResumed() {
    if (!_isPaused) return Future.value();
    _resumeCompleter ??= Completer<void>();
    return _resumeCompleter!.future;
  }

  void incrementChunkIndex() {
    chunkIndex++;
  }
}

class ChunkUploader {
  final String _endPoint;
  final Dio _dio;

  ChunkUploader(this._endPoint, this._dio);

  Future<void> upload(List<int> chunk, String fileName, int fileSize,
      int chunkIndex, ValueNotifier<double> sendProgress) async {
    final mimeType = lookupMimeType(fileName);
    final mediaType = mimeType != null ? MediaType.parse(mimeType) : null;
    FormData formData = FormData.fromMap({
      "chunk": MultipartFile.fromBytes(
        chunk,
        contentType: mediaType,
        filename: '$fileName-chunk-${chunkIndex * chunk.length}',
      ),
      "fileName": fileName,
      "chunkIndex": chunkIndex,
    });

    try {
      final response = await _dio.post(
        _endPoint,
        data: formData,
      );

      if (response.statusCode == 200) {
        sendProgress.value = (chunkIndex * chunk.length) / fileSize;
        print("Uploaded chunk ${(chunkIndex * chunk.length) / fileSize}");
      } else {
        print(
            "Upload failed for chunk ${chunkIndex * chunk.length}: ${response.statusCode}");
      }
    } catch (e) {
      print("Upload failed for chunk ${chunkIndex * chunk.length}: $e");
    }
  }

  Future<void> finalizeUpload(String fileName, int totalChunks) async {
    try {
      await _dio.post(
        '$_endPoint/finalize-upload',
        data: {
          'fileName': fileName,
          'totalChunks': totalChunks,
        },
      );
    } catch (e) {
      print(e);
    }
  }
}

class TimeEstimator {
  int _totalChunksUploaded = 0;
  int _totalTimeTaken = 0;

  void reset() {
    _totalChunksUploaded = 0;
    _totalTimeTaken = 0;
  }

  void update(List<int> chunk, int fileSize, DateTime startTime,
      ValueNotifier<String> remainingTime) {
    DateTime endTime = DateTime.now();
    int chunkUploadTime = endTime.difference(startTime).inMilliseconds;
    _totalChunksUploaded++;
    _totalTimeTaken += chunkUploadTime;
    int remainingChunks =
        (fileSize / chunk.length).ceil() - _totalChunksUploaded;
    int estimatedRemainingTime =
        (_totalTimeTaken ~/ _totalChunksUploaded) * remainingChunks;
    Duration remainingDuration = Duration(milliseconds: estimatedRemainingTime);
    remainingTime.value = _formatDuration(remainingDuration);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
