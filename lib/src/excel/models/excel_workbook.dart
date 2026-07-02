import 'excel_sheet.dart';

class ExcelWorkbook {
  final List<ExcelSheet> sheets;

  const ExcelWorkbook({required this.sheets});

  bool get isEmpty => sheets.isEmpty;

  ExcelSheet? get firstSheet {
    if (sheets.isEmpty) {
      return null;
    }
    return sheets.first;
  }

  ExcelSheet? sheetByName(String name) {
    for (final sheet in sheets) {
      if (sheet.name == name) {
        return sheet;
      }
    }
    return null;
  }
}
