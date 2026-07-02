import 'package:flutter/material.dart';

import '../core/file_preview_kit_theme.dart';
import '../core/file_preview_kit_texts.dart';
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
  final FilePreviewKitTexts? texts;
  final ThemeData? theme;

  const FilePreviewView({
    super.key,
    required this.source,
    this.texts,
    this.theme,
  });

  @override
  State<FilePreviewView> createState() => _FilePreviewViewState();
}

class _FilePreviewViewState extends State<FilePreviewView> {
  late Future<Widget> _previewFuture;
  FilePreviewKitTexts? _resolvedTexts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final texts = _resolveTexts(context);

    if (!identical(_resolvedTexts, texts)) {
      _resolvedTexts = texts;
      _previewFuture = _buildPreview(texts, _resolveTheme());
    }
  }

  @override
  void didUpdateWidget(covariant FilePreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source != widget.source ||
        oldWidget.texts != widget.texts ||
        oldWidget.theme != widget.theme) {
      final texts = _resolveTexts(context);
      _resolvedTexts = texts;
      _previewFuture = _buildPreview(texts, _resolveTheme());
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = _resolveTexts(context);

    return Theme(
      data: _resolveTheme(),
      child: Builder(
        builder: (context) => FutureBuilder<Widget>(
          future: _previewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const PreviewLoadingView();
            }

            if (snapshot.hasError) {
              return PreviewErrorView(
                title: texts.previewFailedTitle,
                message: _errorMessage(snapshot.error, texts),
              );
            }

            return snapshot.data ??
                PreviewErrorView(
                  title: texts.previewFailedTitle,
                  message: texts.unableToPreviewMessage,
                );
          },
        ),
      ),
    );
  }

  Future<Widget> _buildPreview(
    FilePreviewKitTexts texts,
    ThemeData theme,
  ) async {
    final type = _detectType(widget.source);

    switch (type) {
      case PreviewType.xlsx:
        final ExcelWorkbook workbook = XlsxParser().parseBytes(
          widget.source.bytes,
        );

        return ExcelPreviewView(workbook: workbook, texts: texts, theme: theme);

      case PreviewType.unsupported:
        return UnsupportedFileView(
          title: texts.unsupportedFileTitle,
          message: texts.unsupportedFileMessage,
        );
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

  FilePreviewKitTexts _resolveTexts(BuildContext context) {
    return widget.texts ??
        FilePreviewKitTexts.resolve(Localizations.localeOf(context));
  }

  ThemeData _resolveTheme() => widget.theme ?? FilePreviewKitTheme.light;

  String _errorMessage(Object? error, FilePreviewKitTexts texts) {
    if (error is PreviewException) {
      return error.message;
    }

    return texts.unableToPreviewMessage;
  }
}
