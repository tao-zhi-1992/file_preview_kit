/// A rectangular merged cell region in a worksheet.
class ExcelMergeRegion {
  final int startRow;
  final int startColumn;
  final int endRow;
  final int endColumn;

  const ExcelMergeRegion({
    required this.startRow,
    required this.startColumn,
    required this.endRow,
    required this.endColumn,
  });

  int get rowSpan => endRow - startRow + 1;

  int get columnSpan => endColumn - startColumn + 1;

  bool contains(int rowIndex, int columnIndex) {
    return rowIndex >= startRow &&
        rowIndex <= endRow &&
        columnIndex >= startColumn &&
        columnIndex <= endColumn;
  }

  bool isOrigin(int rowIndex, int columnIndex) {
    return rowIndex == startRow && columnIndex == startColumn;
  }
}
