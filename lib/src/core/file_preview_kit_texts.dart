import 'dart:ui';

/// User-facing labels and error messages displayed by preview widgets.
class FilePreviewKitTexts {
  /// Title shown when preview generation fails.
  final String previewFailedTitle;

  /// Generic message shown for an unknown preview failure.
  final String unableToPreviewMessage;

  /// Title shown for unsupported file formats.
  final String unsupportedFileTitle;

  /// Message shown for unsupported file formats.
  final String unsupportedFileMessage;

  /// Message shown when a workbook contains no sheets.
  final String noSheetsFound;

  /// Message shown when the selected sheet is empty.
  final String emptySheet;

  /// Message shown for unsupported visual content inside a DOCX file.
  final String unsupportedDocxContentMessage;

  /// Creates a complete custom text set.
  const FilePreviewKitTexts({
    required this.previewFailedTitle,
    required this.unableToPreviewMessage,
    required this.unsupportedFileTitle,
    required this.unsupportedFileMessage,
    required this.noSheetsFound,
    required this.emptySheet,
    this.unsupportedDocxContentMessage =
        'This document content is not supported yet.',
  });

  /// Default English text.
  const FilePreviewKitTexts.en()
    : previewFailedTitle = 'Preview failed',
      unableToPreviewMessage = 'Unable to preview this file.',
      unsupportedFileTitle = 'Unsupported file type',
      unsupportedFileMessage = 'This file format is not supported yet.',
      noSheetsFound = 'No sheets found',
      emptySheet = 'Empty sheet',
      unsupportedDocxContentMessage =
          'This document content is not supported yet.';

  /// Default Simplified Chinese text.
  const FilePreviewKitTexts.zhHans()
    : previewFailedTitle = '预览失败',
      unableToPreviewMessage = '无法预览此文件。',
      unsupportedFileTitle = '不支持的文件类型',
      unsupportedFileMessage = '暂不支持预览此文件格式。',
      noSheetsFound = '未找到工作表',
      emptySheet = '空工作表',
      unsupportedDocxContentMessage = '暂不支持预览此文档内容。';

  /// Resolves built-in text for [locale].
  static FilePreviewKitTexts resolve(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'zh') {
      return const FilePreviewKitTexts.zhHans();
    }

    return const FilePreviewKitTexts.en();
  }
}
