import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'upload_controller.dart';
// import 'upload_controller_good_1.old.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UploadScreen());
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final uploadState = UploadState();
  late final UploadController uploadController;

  @override
  void initState() {
    super.initState();
    uploadController = UploadController(
      uploadState: uploadState,
    );
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
      // endpoint: 'http://192.168.1.115:3000',
      endpoint: 'http://94.187.8.11:3000',
      headers: {'Authorization': 'Bearer your_token_here'},
    );

    await uploadController.uploadStreamWithProgress(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ValueListenableBuilder<double>(
            //   valueListenable: uploadState.progress,
            //   builder: (context, percentage, child) {
            //     return Text('${(percentage * 100).toStringAsFixed(2)}%');
            //   },
            // ),
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
        ),
      ),
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
          // case UploadStatus.none:
          //   return ElevatedButton(
          //     onPressed: () => uploadController.uploadStreamWithProgress(),
          //     child: const Text('Start Upload'),
          //   );
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
              onPressed: () {},
              child: const Text('Upload Failed'),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
