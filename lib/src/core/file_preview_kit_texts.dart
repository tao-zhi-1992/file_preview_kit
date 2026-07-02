import 'dart:ui';

class FilePreviewKitTexts {
  final String previewFailedTitle;
  final String unableToPreviewMessage;
  final String unsupportedFileTitle;
  final String unsupportedFileMessage;
  final String noSheetsFound;
  final String emptySheet;

  const FilePreviewKitTexts({
    required this.previewFailedTitle,
    required this.unableToPreviewMessage,
    required this.unsupportedFileTitle,
    required this.unsupportedFileMessage,
    required this.noSheetsFound,
    required this.emptySheet,
  });

  const FilePreviewKitTexts.en()
    : previewFailedTitle = 'Preview failed',
      unableToPreviewMessage = 'Unable to preview this file.',
      unsupportedFileTitle = 'Unsupported file type',
      unsupportedFileMessage = 'This file format is not supported yet.',
      noSheetsFound = 'No sheets found',
      emptySheet = 'Empty sheet';

  const FilePreviewKitTexts.zhHans()
    : previewFailedTitle = '预览失败',
      unableToPreviewMessage = '无法预览此文件。',
      unsupportedFileTitle = '不支持的文件类型',
      unsupportedFileMessage = '暂不支持预览此文件格式。',
      noSheetsFound = '未找到工作表',
      emptySheet = '空工作表';

  static FilePreviewKitTexts resolve(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'zh') {
      return const FilePreviewKitTexts.zhHans();
    }

    return const FilePreviewKitTexts.en();
  }
}
