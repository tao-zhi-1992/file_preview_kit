import 'package:flutter/material.dart';

import '../core/preview_source.dart';
import '../core/preview_type.dart';
import '../excel/models/excel_workbook.dart';
import '../excel/parser/xlsx_parser.dart';
import '../excel/widgets/excel_preview_view.dart';

class FilePreviewView extends StatefulWidget {
  final PreviewSource source;

  const FilePreviewView({super.key, required this.source});

  @override
  State<FilePreviewView> createState() => _FilePreviewViewState();
}

class _FilePreviewViewState extends State<FilePreviewView> {
  late Future<Widget> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _buildPreview();
  }

  @override
  void didUpdateWidget(covariant FilePreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source != widget.source) {
      _previewFuture = _buildPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _previewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _PreviewErrorView(message: snapshot.error.toString());
        }

        return snapshot.data ??
            const _PreviewErrorView(message: 'Preview failed');
      },
    );
  }

  Future<Widget> _buildPreview() async {
    final type = _detectType(widget.source);

    switch (type) {
      case PreviewType.xlsx:
        final ExcelWorkbook workbook = XlsxParser().parseBytes(
          widget.source.bytes,
        );

        return ExcelPreviewView(workbook: workbook);

      case PreviewType.unsupported:
        return const _UnsupportedPreviewView();
    }
  }

  PreviewType _detectType(PreviewSource source) {
    final fileName = source.fileName?.toLowerCase();

    if (fileName != null && fileName.endsWith('.xlsx')) {
      return PreviewType.xlsx;
    }

    if (source.mimeType ==
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return PreviewType.xlsx;
    }

    return PreviewType.unsupported;
  }
}

class _UnsupportedPreviewView extends StatelessWidget {
  const _UnsupportedPreviewView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Unsupported file type'));
  }
}

class _PreviewErrorView extends StatelessWidget {
  final String message;

  const _PreviewErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
