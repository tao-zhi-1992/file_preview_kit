import 'package:file_preview_kit/file_preview_kit.dart';
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
}
