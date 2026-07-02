import 'excel_cell_type.dart';

class ExcelCell {
  final int rowIndex;
  final int columnIndex;
  final String address;

  final String rawValue;
  final String displayValue;
  final ExcelCellType type;

  const ExcelCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.address,
    required this.rawValue,
    required this.displayValue,
    required this.type,
  });

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
