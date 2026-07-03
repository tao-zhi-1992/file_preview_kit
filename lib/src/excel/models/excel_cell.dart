import 'excel_cell_type.dart';

/// A parsed spreadsheet cell.
class ExcelCell {
  /// Zero-based row index.
  final int rowIndex;

  /// Zero-based column index.
  final int columnIndex;

  /// A1-style cell address.
  final String address;

  /// Unformatted source value.
  final String rawValue;

  /// Value intended for display.
  final String displayValue;

  /// Parsed value category.
  final ExcelCellType type;

  /// Creates a spreadsheet cell.
  const ExcelCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.address,
    required this.rawValue,
    required this.displayValue,
    required this.type,
  });

  /// Creates an empty cell at the specified position.
  factory ExcelCell.blank({
    required int rowIndex,
    required int columnIndex,
    required String address,
  }) {
    return ExcelCell(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      address: address,
      rawValue: '',
      displayValue: '',
      type: ExcelCellType.blank,
    );
  }
}
