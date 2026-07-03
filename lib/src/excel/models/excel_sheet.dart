import 'excel_cell.dart';
import 'excel_merge_region.dart';

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

  /// Column widths in pixels keyed by zero-based column index.
  final Map<int, double> columnWidths;

  /// Merged cell regions in the worksheet.
  final List<ExcelMergeRegion> mergeRegions;

  /// Creates a worksheet.
  const ExcelSheet({
    required this.name,
    required this.rowCount,
    required this.columnCount,
    required this.rows,
    this.columnWidths = const {},
    this.mergeRegions = const [],
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

  /// Returns the merge region covering [rowIndex] and [columnIndex], if any.
  ExcelMergeRegion? mergeRegionAt(int rowIndex, int columnIndex) {
    for (final region in mergeRegions) {
      if (region.contains(rowIndex, columnIndex)) {
        return region;
      }
    }
    return null;
  }

  /// Whether [rowIndex] and [columnIndex] are covered by a merge but not the origin.
  bool isMergeCovered(int rowIndex, int columnIndex) {
    final region = mergeRegionAt(rowIndex, columnIndex);
    return region != null && !region.isOrigin(rowIndex, columnIndex);
  }
}
