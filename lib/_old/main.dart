// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('Upload Control')),
//         body: const Center(child: MyHomePage()),
//       ),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key});

//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final UploadController _uploadController = UploadController(
//     endPoint: 'http://localhost:3000/upload',
//   );

//   @override
//   void dispose() {
//     _uploadController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         ElevatedButton(
//           onPressed: () async {
//             final result = await FilePicker.platform.pickFiles(
//               withReadStream: true,
//             );

//             if (result == null) return;
//             if (result.files.isEmpty) return;

//             final file = result.files[0];

//             if (file.readStream == null) return;

//             await _uploadController.uploadStreamWithProgress(
//               file.readStream!,
//               file.name,
//               file.size,
//             );
//           },
//           child: const Text('Start Upload'),
//         ),
//         FileUploadWidget(
//           controller: _uploadController,
//         ),
//       ],
//     );
//   }
// }

// class FileUploadWidget extends StatefulWidget {
//   const FileUploadWidget({
//     super.key,
//     required this.controller,
//   });
//   final UploadController controller;

//   @override
//   _FileUploadWidgetState createState() => _FileUploadWidgetState();
// }

// class _FileUploadWidgetState extends State<FileUploadWidget> {
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           ValueListenableBuilder<double>(
//             valueListenable: widget.controller.sendProgress,
//             builder: (context, progress, child) {
//               return CircularProgressIndicator(value: progress);
//             },
//           ),
//           const SizedBox(height: 16),
//           ValueListenableBuilder<String>(
//             valueListenable: widget.controller.remainingTime,
//             builder: (context, time, child) {
//               return Text('Remaining time: $time');
//             },
//           ),
//           const SizedBox(height: 16),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               ElevatedButton(
//                 onPressed: widget.controller.pause,
//                 child: const Text('Pause'),
//               ),
//               ElevatedButton(
//                 onPressed: widget.controller.resume,
//                 child: const Text('Resume'),
//               ),
//               ElevatedButton(
//                 onPressed: widget.controller.cancel,
//                 child: const Text('Cancel'),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
