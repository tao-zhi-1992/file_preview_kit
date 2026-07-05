import 'package:flutter/material.dart';

import '../models/excel_cell_borders.dart';
import '../models/excel_merge_region.dart';
import '../models/excel_sheet.dart';

/// Resolves which cell borders to paint without doubling shared edges.
class ExcelBorderResolver {
  ExcelBorderResolver._();

  /// Returns the borders [sheet] should paint for a cell at [rowIndex] and
  /// [columnIndex], optionally spanning [mergeRegion].
  static ExcelCellBorders resolve(
    ExcelSheet sheet, {
    required int rowIndex,
    required int columnIndex,
    ExcelMergeRegion? mergeRegion,
  }) {
    final originRow = mergeRegion?.startRow ?? rowIndex;
    final originColumn = mergeRegion?.startColumn ?? columnIndex;
    final endRow = mergeRegion?.endRow ?? rowIndex;
    final endColumn = mergeRegion?.endColumn ?? columnIndex;

    final left = _borderAt(
      sheet,
      originRow,
      originColumn,
      (borders) => borders.left,
    );
    final right =
        _borderAt(sheet, originRow, endColumn, (borders) => borders.right) ??
        _borderAt(sheet, originRow, originColumn, (borders) => borders.right);
    final top = _borderAt(
      sheet,
      originRow,
      originColumn,
      (borders) => borders.top,
    );
    final bottom =
        _borderAt(sheet, endRow, originColumn, (borders) => borders.bottom) ??
        _borderAt(sheet, originRow, originColumn, (borders) => borders.bottom);

    return ExcelCellBorders(
      left:
          _ownsEdge(
            own: left,
            neighbor: _borderAt(
              sheet,
              originRow,
              originColumn - 1,
              (borders) => borders.right,
            ),
            ownWinsTie: true,
          )
          ? left
          : null,
      right:
          _ownsEdge(
            own: right,
            neighbor: _borderAt(
              sheet,
              originRow,
              endColumn + 1,
              (borders) => borders.left,
            ),
            ownWinsTie: false,
          )
          ? right
          : null,
      top:
          _ownsEdge(
            own: top,
            neighbor: _borderAt(
              sheet,
              originRow - 1,
              originColumn,
              (borders) => borders.bottom,
            ),
            ownWinsTie: true,
          )
          ? top
          : null,
      bottom:
          _ownsEdge(
            own: bottom,
            neighbor: _borderAt(
              sheet,
              endRow + 1,
              originColumn,
              (borders) => borders.top,
            ),
            ownWinsTie: false,
          )
          ? bottom
          : null,
    );
  }

  static BorderSide? _borderAt(
    ExcelSheet sheet,
    int rowIndex,
    int columnIndex,
    BorderSide? Function(ExcelCellBorders borders) pick,
  ) {
    final cell = sheet.cellAt(rowIndex, columnIndex);
    if (cell == null) {
      return null;
    }

    return pick(cell.style.borders);
  }

  static bool _ownsEdge({
    required BorderSide? own,
    required BorderSide? neighbor,
    required bool ownWinsTie,
  }) {
    if (own == null) {
      return false;
    }

    if (neighbor == null) {
      return true;
    }

    if (own.width > neighbor.width) {
      return true;
    }

    if (own.width < neighbor.width) {
      return false;
    }

    return ownWinsTie;
  }
}
