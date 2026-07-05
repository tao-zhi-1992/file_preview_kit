import '../csv/parser/csv_parser.dart';
import '../excel/models/excel_workbook.dart';
import '../excel/parser/xlsx_parser.dart';
import '../word/models/docx_document.dart';
import '../word/parser/docx_parser.dart';
import 'preview_source.dart';
import 'preview_type.dart';

/// Parsed preview payload returned by [FilePreviewLoader.load].
sealed class PreviewContent {
  const PreviewContent();
}

/// Parsed XLSX workbook content.
final class XlsxPreviewContent extends PreviewContent {
  /// Parsed workbook.
  final ExcelWorkbook workbook;

  /// Creates XLSX preview content.
  const XlsxPreviewContent(this.workbook);
}

/// Parsed CSV workbook content.
final class CsvPreviewContent extends PreviewContent {
  /// Parsed workbook rendered in the spreadsheet grid.
  final ExcelWorkbook workbook;

  /// Creates CSV preview content.
  const CsvPreviewContent(this.workbook);
}

/// Parsed DOCX document content.
final class DocxPreviewContent extends PreviewContent {
  /// Parsed document.
  final DocxDocument document;

  /// Creates DOCX preview content.
  const DocxPreviewContent(this.document);
}

/// Content for an unsupported file type.
final class UnsupportedPreviewContent extends PreviewContent {
  /// Creates unsupported preview content.
  const UnsupportedPreviewContent();
}

/// Detects and parses supported in-memory preview sources.
class FilePreviewLoader {
  const FilePreviewLoader._();

  /// Detects the preview type from file name and MIME metadata.
  static PreviewType detectType(PreviewSource source) {
    final fileName = source.fileName?.toLowerCase();

    if (fileName != null && fileName.endsWith('.xlsx')) {
      return PreviewType.xlsx;
    }

    if (fileName != null && fileName.endsWith('.csv')) {
      return PreviewType.csv;
    }

    if (fileName != null && fileName.endsWith('.docx')) {
      return PreviewType.docx;
    }

    if (source.mimeType ==
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
      return PreviewType.xlsx;
    }

    if (source.mimeType == 'text/csv' || source.mimeType == 'application/csv') {
      return PreviewType.csv;
    }

    if (source.mimeType ==
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return PreviewType.docx;
    }

    return PreviewType.unsupported;
  }

  /// Parses [source] bytes into preview content.
  static Future<PreviewContent> load(PreviewSource source) async {
    switch (detectType(source)) {
      case PreviewType.xlsx:
        return XlsxPreviewContent(const XlsxParser().parseBytes(source.bytes));
      case PreviewType.csv:
        return CsvPreviewContent(const CsvParser().parseBytes(source.bytes));
      case PreviewType.docx:
        return DocxPreviewContent(const DocxParser().parseBytes(source.bytes));
      case PreviewType.unsupported:
        return const UnsupportedPreviewContent();
    }
  }
}
