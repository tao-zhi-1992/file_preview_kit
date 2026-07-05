import 'package:flutter/material.dart';

import '../core/file_preview_kit_theme.dart';
import '../core/file_preview_kit_texts.dart';
import '../core/preview_exception.dart';
import '../core/preview_loader.dart';
import '../core/preview_source.dart';
import '../excel/widgets/excel_preview_view.dart';
import '../word/widgets/docx_preview_view.dart';
import 'preview_error_view.dart';
import 'preview_loading_view.dart';
import 'unsupported_file_view.dart';

/// Detects, parses, and previews a supported in-memory file.
class FilePreviewView extends StatefulWidget {
  /// File content and format metadata.
  final PreviewSource source;

  /// Optional user-facing text overrides.
  final FilePreviewKitTexts? texts;

  /// Optional theme applied within the preview.
  final ThemeData? theme;

  /// Called when a DOCX hyperlink or bookmark is activated.
  final ValueChanged<String>? onLinkTap;

  /// Creates a unified file preview.
  const FilePreviewView({
    super.key,
    required this.source,
    this.texts,
    this.theme,
    this.onLinkTap,
  });

  @override
  State<FilePreviewView> createState() => _FilePreviewViewState();
}

class _FilePreviewViewState extends State<FilePreviewView> {
  late Future<PreviewContent> _previewFuture;
  FilePreviewKitTexts? _resolvedTexts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final texts = _resolveTexts(context);

    if (!identical(_resolvedTexts, texts)) {
      _resolvedTexts = texts;
      _previewFuture = FilePreviewLoader.load(widget.source);
    }
  }

  @override
  void didUpdateWidget(covariant FilePreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.source != widget.source ||
        oldWidget.texts != widget.texts ||
        oldWidget.theme != widget.theme ||
        oldWidget.onLinkTap != widget.onLinkTap) {
      final texts = _resolveTexts(context);
      _resolvedTexts = texts;
      _previewFuture = FilePreviewLoader.load(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = _resolveTexts(context);
    final theme = _resolveTheme();

    return Theme(
      data: theme,
      child: FutureBuilder<PreviewContent>(
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

          final content = snapshot.data;
          if (content == null) {
            return PreviewErrorView(
              title: texts.previewFailedTitle,
              message: texts.unableToPreviewMessage,
            );
          }

          return _widgetForContent(content, texts: texts, theme: theme);
        },
      ),
    );
  }

  Widget _widgetForContent(
    PreviewContent content, {
    required FilePreviewKitTexts texts,
    required ThemeData theme,
  }) {
    return switch (content) {
      XlsxPreviewContent(:final workbook) => ExcelPreviewView(
        workbook: workbook,
        texts: texts,
        theme: theme,
      ),
      CsvPreviewContent(:final workbook) => ExcelPreviewView(
        workbook: workbook,
        texts: texts,
        theme: theme,
      ),
      DocxPreviewContent(:final document) => DocxPreviewView(
        document: document,
        theme: theme,
        onLinkTap: widget.onLinkTap,
      ),
      UnsupportedPreviewContent() => UnsupportedFileView(
        title: texts.unsupportedFileTitle,
        message: texts.unsupportedFileMessage,
      ),
    };
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
