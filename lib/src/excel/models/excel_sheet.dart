import 'excel_cell.dart';
import 'excel_cell_borders.dart';
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

  /// O(1) lookup of merge regions by cell coordinates.
  final Map<(int, int), ExcelMergeRegion> _mergeByCell;

  /// Lazily filled display borders keyed by merge/cell origin.
  final Map<(int, int), ExcelCellBorders> _resolvedBorders = {};

  /// Creates a worksheet.
  ExcelSheet({
    required this.name,
    required this.rowCount,
    required this.columnCount,
    required this.rows,
    this.columnWidths = const {},
    this.mergeRegions = const [],
  }) : _mergeByCell = _buildMergeIndex(mergeRegions);

  static Map<(int, int), ExcelMergeRegion> _buildMergeIndex(
    List<ExcelMergeRegion> regions,
  ) {
    if (regions.isEmpty) {
      return const {};
    }

    final index = <(int, int), ExcelMergeRegion>{};
    for (final region in regions) {
      for (var row = region.startRow; row <= region.endRow; row++) {
        for (
          var column = region.startColumn;
          column <= region.endColumn;
          column++
        ) {
          index[(row, column)] = region;
        }
      }
    }
    return index;
  }

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
    if (_mergeByCell.isEmpty) {
      return null;
    }

    return _mergeByCell[(rowIndex, columnIndex)];
  }

  /// Whether [rowIndex] and [columnIndex] are covered by a merge but not the origin.
  bool isMergeCovered(int rowIndex, int columnIndex) {
    final region = mergeRegionAt(rowIndex, columnIndex);
    return region != null && !region.isOrigin(rowIndex, columnIndex);
  }

  /// Returns cached display borders for an origin cell, computing them once.
  ExcelCellBorders resolvedBordersAt({
    required int originRow,
    required int originColumn,
    required ExcelCellBorders Function() compute,
  }) {
    final key = (originRow, originColumn);
    final cached = _resolvedBorders[key];
    if (cached != null) {
      return cached;
    }

    final resolved = compute();
    _resolvedBorders[key] = resolved;
    return resolved;
  }
}
