import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads workbook cells safely', () {
    final cell = ExcelCell.blank(rowIndex: 0, columnIndex: 0, address: 'A1');
    final sheet = ExcelSheet(
      name: 'Sheet1',
      rowCount: 1,
      columnCount: 1,
      rows: [
        [cell],
      ],
    );
    final workbook = ExcelWorkbook(sheets: [sheet]);

    expect(workbook.firstSheet, sheet);
    expect(workbook.sheetByName('Sheet1'), sheet);
    expect(sheet.cellAt(0, 0), cell);
    expect(sheet.cellAt(1, 0), isNull);
    expect(cell.style, same(ExcelCellStyle.empty));
  });

  test('indexes merge regions for O(1) lookup', () {
    const regionA = ExcelMergeRegion(
      startRow: 0,
      startColumn: 0,
      endRow: 1,
      endColumn: 1,
    );
    const regionB = ExcelMergeRegion(
      startRow: 3,
      startColumn: 2,
      endRow: 3,
      endColumn: 4,
    );
    final sheet = ExcelSheet(
      name: 'Merged',
      rowCount: 5,
      columnCount: 5,
      rows: [
        for (var row = 0; row < 5; row++)
          [
            for (var column = 0; column < 5; column++)
              ExcelCell.blank(
                rowIndex: row,
                columnIndex: column,
                address: 'R${row + 1}C${column + 1}',
              ),
          ],
      ],
      mergeRegions: const [regionA, regionB],
    );

    expect(sheet.mergeRegionAt(0, 0), same(regionA));
    expect(sheet.mergeRegionAt(1, 1), same(regionA));
    expect(sheet.mergeRegionAt(3, 3), same(regionB));
    expect(sheet.mergeRegionAt(2, 2), isNull);
    expect(sheet.isMergeCovered(0, 0), isFalse);
    expect(sheet.isMergeCovered(1, 1), isTrue);
  });

  test('caches resolved borders by origin cell', () {
    var computeCount = 0;
    final sheet = ExcelSheet(
      name: 'Borders',
      rowCount: 1,
      columnCount: 1,
      rows: [
        [ExcelCell.blank(rowIndex: 0, columnIndex: 0, address: 'A1')],
      ],
    );
    const borders = ExcelCellBorders(
      left: BorderSide(color: Color(0xFF0000FF), width: 0.5),
    );

    final first = sheet.resolvedBordersAt(
      originRow: 0,
      originColumn: 0,
      compute: () {
        computeCount += 1;
        return borders;
      },
    );
    final second = sheet.resolvedBordersAt(
      originRow: 0,
      originColumn: 0,
      compute: () {
        computeCount += 1;
        return borders;
      },
    );

    expect(first, same(borders));
    expect(second, same(borders));
    expect(computeCount, 1);
  });
}
