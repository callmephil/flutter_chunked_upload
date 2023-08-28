import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class ProgressTracker {
  final ValueNotifier<double> sendProgress = ValueNotifier<double>(0);
  final ValueNotifier<String> remainingTime = ValueNotifier<String>('');

  int _totalChunksUploaded = 0;
  int _totalTimeTaken = 0;

  void updateProgress(
      int fileSize, int chunkSize, DateTime startTime, DateTime endTime) {
    int chunkUploadTime = endTime.difference(startTime).inMilliseconds;
    _totalChunksUploaded++;
    _totalTimeTaken += chunkUploadTime;
    int remainingChunks = (fileSize / chunkSize).ceil() - _totalChunksUploaded;
    int estimatedRemainingTime =
        (_totalTimeTaken ~/ _totalChunksUploaded) * remainingChunks;
    Duration remainingDuration = Duration(milliseconds: estimatedRemainingTime);
    remainingTime.value = remainingDuration.toString();
  }
}

class UploadController extends ChangeNotifier {
  final ProgressTracker _progressTracker = ProgressTracker();
  StreamSubscription<List<int>>? _chunkStreamSubscription;

  ValueNotifier<double> get progress => _progressTracker.sendProgress;
  ValueNotifier<String> get remainingTime => _progressTracker.remainingTime;

  Future<void> uploadStreamWithProgress(
    Stream<List<int>> readStream,
    String fileName,
    int fileSize,
  ) async {
    int chunkSize = 1024 * 1024; // 1 MB
    int chunkIndex = 0;

    _chunkStreamSubscription = readStream.listen((chunk) async {
      _chunkStreamSubscription?.pause();
      DateTime startTime = DateTime.now();
      await CommunicationController()
          .uploadChunk(chunk, fileName, fileSize, chunkIndex, chunkSize)
          .then(
        (value) {
          _chunkStreamSubscription?.resume();
          chunkIndex++;

          DateTime endTime = DateTime.now();
          _progressTracker.updateProgress(
              fileSize, chunkSize, startTime, endTime);
        },
      );
    });

    _chunkStreamSubscription?.onDone(() {
      // Handle upload completion here
    });
  }
}

class CommunicationController {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  Future<void> uploadChunk(
    List<int> chunk,
    String fileName,
    int fileSize,
    int chunkIndex,
    int chunkSize,
  ) async {
    final mimeType = lookupMimeType(fileName);
    final mediaType = mimeType != null ? MediaType.parse(mimeType) : null;
    FormData formData = FormData.fromMap({
      'chunk': MultipartFile.fromBytes(
        chunk,
        contentType: mediaType,
        filename: '$fileName-chunk-\${chunkIndex * chunkSize}',
      ),
      'fileName': fileName,
      'chunkIndex': chunkIndex,
    });

    _cancelToken = CancelToken();

    try {
      final response = await _dio.post(
        'http://localhost:3000/upload',
        data: formData,
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200) {
        print('Uploaded chunk ${(chunkIndex * chunkSize) / fileSize}');
      } else {
        print(
            'Upload failed for chunk \${chunkIndex * chunkSize}: \${response.statusCode}');
      }
    } catch (e) {
      print('Upload failed for chunk \${chunkIndex * chunkSize}: $e');
    }
  }

  Future<void> finalizeUpload(String fileName, int totalChunks) async {
    try {
      await _dio.post(
        'http://localhost:3000/finalize-upload',
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
