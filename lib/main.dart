import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'upload_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Upload Screen')),
        body: const Center(child: UploadScreen()),
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  UploadState uploadState = UploadState();
  UploadController uploadController = UploadController(
    uploadState: UploadState(),
    config: UploadConfig(
      readStream: const Stream.empty(),
      fileName: '',
      fileSize: 0,
      endpoint: '',
    ),
  );

  @override
  void initState() {
    super.initState();
  }

  Future<void> startUpload() async {
    final result = await FilePicker.platform.pickFiles(
      withReadStream: true,
    );

    if (result == null) return;
    if (result.files.isEmpty) return;

    final file = result.files[0];

    if (file.readStream == null) return;

    final config = UploadConfig(
      readStream: file.readStream!,
      fileName: file.name,
      fileSize: file.size,
      endpoint: 'http://192.168.8.139:3000',
      // headers: {'Authorization': 'Bearer your_token_here'},
    );

    setState(() {
      uploadState = UploadState();
      uploadController = UploadController(
        uploadState: uploadState,
        config: config,
      );
    });

    await uploadController.uploadStreamWithProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: uploadState.remainingTime,
          builder: (context, time, _) {
            return Text('Remaining Time:  $time');
          },
        ),
        ValueListenableBuilder<UploadStatus>(
          valueListenable: uploadState.status,
          builder: (context, status, _) {
            return Text('Upload Status: $status');
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: uploadState.progress,
          builder: (context, progressValue, child) {
            return LinearProgressIndicator(value: progressValue);
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: uploadState.progress,
          builder: (context, progressValue, child) {
            return Text(progressValue.toPercentageString());
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: startUpload,
          child: const Text('Start Upload'),
        ),
        const SizedBox(height: 8),
        UploadButtonWidget(
          uploadController: uploadController,
          uploadState: uploadState,
        ),
      ],
    );
  }
}

class UploadButtonWidget extends StatelessWidget {
  final UploadState uploadState;
  final UploadController uploadController;

  const UploadButtonWidget({
    super.key,
    required this.uploadState,
    required this.uploadController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: uploadState.status,
      builder: (context, status, _) {
        switch (status) {
          case UploadStatus.uploading:
            return Row(
              children: [
                ElevatedButton(
                  onPressed: uploadController.pause,
                  child: const Text('Pause'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: uploadController.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            );
          case UploadStatus.paused:
            return Row(
              children: [
                ElevatedButton(
                  onPressed: uploadController.resume,
                  child: const Text('Resume'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: uploadController.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            );
          case UploadStatus.completed:
            return ElevatedButton(
              onPressed: () {},
              child: const Text('Upload Completed'),
            );
          case UploadStatus.failed:
            return ElevatedButton(
              onPressed: () async {
                // do a dio post request to /cancel-upload with the fileName
                // and the endpoint will cancel the upload
              },
              child: const Text('Upload Failed'),
            );

          case UploadStatus.canceled:
            return ElevatedButton(
              onPressed: () {},
              child: const Text('Upload Canceled'),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
