import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Preview Kit Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
        ),
        useMaterial3: true,
      ),
      home: const ExcelPreviewExamplePage(),
    );
  }
}

class ExcelPreviewExamplePage extends StatefulWidget {
  const ExcelPreviewExamplePage({super.key});

  @override
  State<ExcelPreviewExamplePage> createState() =>
      _ExcelPreviewExamplePageState();
}

class _ExcelPreviewExamplePageState extends State<ExcelPreviewExamplePage> {
  Uint8List? _bytes;
  String? _fileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'docx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;

    if (file.bytes == null) {
      return;
    }

    setState(() {
      _bytes = file.bytes;
      _fileName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final fileName = _fileName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Preview'),
        actions: [
          IconButton(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open file',
          ),
        ],
      ),
      body: bytes == null
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose XLSX, CSV, or DOCX file'),
              ),
            )
          : FilePreviewView(
              source: PreviewSource.bytes(bytes, fileName: fileName),
            ),
    );
  }
}
