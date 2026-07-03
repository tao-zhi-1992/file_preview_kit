import 'excel_cell.dart';

/// A parsed spreadsheet worksheet.
class ExcelSheet {
  /// Worksheet name.
  final String name;

  /// Number of parsed rows.
  final int rowCount;

  /// Maximum number of parsed columns.
  final int columnCount;

  /// Rectangular cell data indexed by row and column.
  final List<List<ExcelCell>> rows;

  /// Creates a worksheet.
  const ExcelSheet({
    required this.name,
    required this.rowCount,
    required this.columnCount,
    required this.rows,
  });

  /// Whether the worksheet contains no rows.
  bool get isEmpty => rows.isEmpty;

  /// Returns a cell by zero-based position, or `null` when out of bounds.
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
