import 'excel_cell_style.dart';

/// Parsed workbook styles from `xl/styles.xml`.
class ExcelStylesParseResult {
  final List<ExcelCellStyle> styles;
  final List<String?> numberFormats;

  const ExcelStylesParseResult({
    required this.styles,
    required this.numberFormats,
  });

  static const empty = ExcelStylesParseResult(styles: [], numberFormats: []);
}
