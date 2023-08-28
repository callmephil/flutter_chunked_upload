import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class UploadController extends ChangeNotifier {
  final Dio _dio = Dio();
  late final CancelToken _cancelToken;
  late final StreamSubscription<List<int>> _chunkStreamSubscription;
  late bool _isPaused;
  final int _chunkSize = 1024 * 1024; // 1MB

  final ValueNotifier<double> sendProgress = ValueNotifier<double>(0);

  UploadController()
      : _cancelToken = CancelToken(),
        _isPaused = false;

  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      _chunkStreamSubscription.pause();
    }
  }

  void resume() {
    if (_isPaused) {
      _isPaused = false;
      _chunkStreamSubscription.resume();
    }
  }

  void cancel() {
    _cancelToken.cancel();
    _chunkStreamSubscription.cancel();
    sendProgress.value = 0;
  }

  Future<void> uploadStreamWithProgress({
    required Stream<List<int>> readStream,
    required String fileName,
    required int fileSize,
  }) async {
    var chunkIndex = 0;

    final chunkStreamController = StreamController<List<int>>();
    _isPaused = false;

    // Process the incoming data chunks
    _chunkStreamSubscription = readStream.listen(
      (chunk) async {
        _chunkStreamSubscription.pause();
        chunkStreamController.add(chunk);

        await _uploadChunk(
          chunk: chunk,
          fileName: fileName,
          fileSize: fileSize,
          chunkIndex: chunkIndex,
        );

        chunkIndex++;
        _chunkStreamSubscription.resume();
      },
      // Finalize the upload when done
      onDone: () async {
        await _finalizeUpload(fileName, chunkIndex);
        chunkStreamController.close();
        print('Upload completed, closing stream');
      },
    );
  }

  Future<void> _uploadChunk({
    required List<int> chunk,
    required String fileName,
    required int fileSize,
    required int chunkIndex,
  }) async {
    final mimeType = lookupMimeType(fileName);
    final mediaType = mimeType != null ? MediaType.parse(mimeType) : null;
    final formData = FormData.fromMap({
      "chunk": MultipartFile.fromBytes(
        chunk,
        contentType: mediaType,
        filename: '$fileName-chunk-${chunkIndex + 1}',
      ),
      "fileName": fileName,
      "chunkIndex": chunkIndex,
    });

    try {
      final response = await _dio.post(
        "http://localhost:3000/upload",
        data: formData,
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200) {
        sendProgress.value = (chunkIndex * _chunkSize) / fileSize;
        print("Uploaded chunk ${(chunkIndex * _chunkSize) / fileSize}");
      } else {
        print(
          "Upload failed for chunk ${chunkIndex * _chunkSize}: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("Upload failed for chunk ${chunkIndex * _chunkSize}: $e");
    }
  }

  Future<void> _finalizeUpload(String fileName, int totalChunks) async {
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
