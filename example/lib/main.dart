import 'package:file_picker/file_picker.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<void> _openDemo(String path) async {
    final data = await rootBundle.load(path);

    setState(() {
      _bytes = data.buffer.asUint8List();
      _fileName = path.split('/').last;
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
          ? _FileActions(onPickFile: _pickFile, onOpenDemo: _openDemo)
          : FilePreviewView(
              source: PreviewSource.bytes(bytes, fileName: fileName),
            ),
    );
  }
}

class _FileActions extends StatelessWidget {
  const _FileActions({required this.onPickFile, required this.onOpenDemo});

  final VoidCallback onPickFile;
  final ValueChanged<String> onOpenDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: onPickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose XLSX, CSV, or DOCX file'),
          ),
          const SizedBox(height: 16),
          for (final demo in _demoFiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => onOpenDemo(demo.path),
                child: Text(demo.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoFile {
  const _DemoFile({required this.label, required this.path});

  final String label;
  final String path;
}

const _demoFiles = [
  _DemoFile(
    label: 'Open project management demo',
    path: 'assets/Project-Management-Sample-Data.xlsx',
  ),
  _DemoFile(
    label: 'Open large XLSX demo',
    path: 'assets/file_example_XLSX_5000.xlsx',
  ),
  _DemoFile(label: 'Open DOCX demo', path: 'assets/file-sample_1MB.docx'),
];
