import 'excel_sheet.dart';

/// A parsed XLSX or CSV workbook.
class ExcelWorkbook {
  /// Worksheets in source order.
  final List<ExcelSheet> sheets;

  /// Creates a workbook from [sheets].
  const ExcelWorkbook({required this.sheets});

  /// Whether the workbook contains no worksheets.
  bool get isEmpty => sheets.isEmpty;

  /// First worksheet, or `null` when the workbook is empty.
  ExcelSheet? get firstSheet {
    if (sheets.isEmpty) {
      return null;
    }
    return sheets.first;
  }

  /// Finds a worksheet by its exact [name].
  ExcelSheet? sheetByName(String name) {
    for (final sheet in sheets) {
      if (sheet.name == name) {
        return sheet;
      }
    }
    return null;
  }
}
