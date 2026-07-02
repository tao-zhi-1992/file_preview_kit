import 'excel_cell.dart';

class ExcelSheet {
  final String name;
  final int rowCount;
  final int columnCount;
  final List<List<ExcelCell>> rows;

  const ExcelSheet({
    required this.name,
    required this.rowCount,
    required this.columnCount,
    required this.rows,
  });

  bool get isEmpty => rows.isEmpty;

  ExcelCell? cellAt(int rowIndex, int columnIndex) {
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return null;
    }

    final row = rows[rowIndex];

    if (columnIndex < 0 || columnIndex >= row.length) {
      return null;
    }

    return row[columnIndex];
  }
}
