import 'package:flutter/material.dart';

import '../core/preview_exception.dart';
import '../core/preview_source.dart';
import '../core/preview_type.dart';
import '../excel/models/excel_workbook.dart';
import '../excel/parser/xlsx_parser.dart';
import '../excel/widgets/excel_preview_view.dart';
import 'preview_error_view.dart';
import 'preview_loading_view.dart';
import 'unsupported_file_view.dart';

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
          return const PreviewLoadingView();
        }

        if (snapshot.hasError) {
          return PreviewErrorView(message: _errorMessage(snapshot.error));
        }

        return snapshot.data ??
            const PreviewErrorView(message: 'Preview failed');
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
        return const UnsupportedFileView();
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

  String _errorMessage(Object? error) {
    if (error is PreviewException) {
      return error.message;
    }

    return 'Unable to preview this file.';
  }
}
