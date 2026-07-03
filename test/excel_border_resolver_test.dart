import 'package:file_preview_kit/src/excel/models/excel_cell.dart';
import 'package:file_preview_kit/src/excel/models/excel_cell_borders.dart';
import 'package:file_preview_kit/src/excel/models/excel_cell_style.dart';
import 'package:file_preview_kit/src/excel/models/excel_cell_type.dart';
import 'package:file_preview_kit/src/excel/models/excel_merge_region.dart';
import 'package:file_preview_kit/src/excel/models/excel_sheet.dart';
import 'package:file_preview_kit/src/excel/parser/excel_border_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const thinBlue = BorderSide(color: Color(0xFF0000FF), width: 0.5);

  ExcelSheet sheetWithRows(List<List<ExcelCell>> rows) {
    return ExcelSheet(
      name: 'Borders',
      rowCount: rows.length,
      columnCount: rows.first.length,
      rows: rows,
    );
  }

  ExcelCell cell({
    required int row,
    required int column,
    ExcelCellBorders borders = ExcelCellBorders.empty,
  }) {
    return ExcelCell(
      rowIndex: row,
      columnIndex: column,
      address: 'R${row + 1}C${column + 1}',
      rawValue: 'Sample',
      displayValue: 'Sample',
      type: ExcelCellType.string,
      style: ExcelCellStyle(borders: borders),
    );
  }

  group('ExcelBorderResolver', () {
    test('draws a single border between two adjacent thin cells', () {
      final sheet = sheetWithRows([
        [
          cell(
            row: 0,
            column: 0,
            borders: const ExcelCellBorders(right: thinBlue),
          ),
          cell(
            row: 0,
            column: 1,
            borders: const ExcelCellBorders(left: thinBlue),
          ),
        ],
      ]);

      final left = ExcelBorderResolver.resolve(sheet, rowIndex: 0, columnIndex: 0);
      final right = ExcelBorderResolver.resolve(sheet, rowIndex: 0, columnIndex: 1);

      expect(left.right, isNull);
      expect(right.left, thinBlue);
    });

    test('keeps the thicker border on a shared edge', () {
      const thickBlue = BorderSide(color: Color(0xFF0000FF), width: 1.5);

      final sheet = sheetWithRows([
        [
          cell(
            row: 0,
            column: 0,
            borders: const ExcelCellBorders(right: thinBlue),
          ),
          cell(
            row: 0,
            column: 1,
            borders: const ExcelCellBorders(left: thickBlue),
          ),
        ],
      ]);

      final left = ExcelBorderResolver.resolve(sheet, rowIndex: 0, columnIndex: 0);
      final right = ExcelBorderResolver.resolve(sheet, rowIndex: 0, columnIndex: 1);

      expect(left.right, isNull);
      expect(right.left, thickBlue);
    });

    test('uses outer edges for merged regions', () {
      final sheet = ExcelSheet(
        name: 'Merged',
        rowCount: 1,
        columnCount: 3,
        mergeRegions: const [
          ExcelMergeRegion(
            startRow: 0,
            startColumn: 0,
            endRow: 0,
            endColumn: 2,
          ),
        ],
        rows: [
          [
            cell(
              row: 0,
              column: 0,
              borders: const ExcelCellBorders(
                left: thinBlue,
                right: thinBlue,
              ),
            ),
            cell(row: 0, column: 1),
            cell(row: 0, column: 2),
          ],
        ],
      );

      final resolved = ExcelBorderResolver.resolve(
        sheet,
        rowIndex: 0,
        columnIndex: 0,
        mergeRegion: sheet.mergeRegions.single,
      );

      expect(resolved.left, thinBlue);
      expect(resolved.right, thinBlue);
    });
  });
}
