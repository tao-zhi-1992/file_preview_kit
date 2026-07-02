import 'dart:io';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExcelWorkbook readWorkbook(String name) {
    final bytes = File('test/fixtures/xlsx/$name').readAsBytesSync();
    return XlsxParser().parseBytes(bytes);
  }

  group('XlsxParser fixtures', () {
    test('01 simple data', () {
      final sheet = readWorkbook('01_simple.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, 'Name');
      expect(sheet.cellAt(1, 0)?.displayValue, 'Sample User A');
      expect(sheet.cellAt(1, 1)?.displayValue, '18');
      expect(sheet.cellAt(1, 2)?.displayValue, '100.5');
    });

    test('02 multi sheet', () {
      final workbook = readWorkbook('02_multi_sheet.xlsx');

      expect(workbook.sheets.length, 2);
      expect(workbook.sheets[0].name, 'Inventory');
      expect(workbook.sheets[1].name, 'Customers');
      expect(workbook.sheets[0].cellAt(1, 0)?.displayValue, 'Sample Item');
      expect(workbook.sheets[1].cellAt(1, 0)?.displayValue, 'Sample Customer');
    });

    test('03 empty cells', () {
      final sheet = readWorkbook('03_empty_cells.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, 'Name');
      expect(sheet.cellAt(0, 1)?.displayValue, '');
      expect(sheet.cellAt(0, 2)?.displayValue, 'Age');
      expect(sheet.cellAt(1, 0)?.displayValue, '');
      expect(sheet.cellAt(1, 1)?.displayValue, '');
      expect(sheet.cellAt(1, 2)?.displayValue, '');
      expect(sheet.cellAt(2, 0)?.displayValue, 'Sample User');
      expect(sheet.cellAt(2, 2)?.displayValue, '18');
    });

    test('04 inline string', () {
      final sheet = readWorkbook('04_inline_string.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, 'Type');
      expect(sheet.cellAt(0, 1)?.displayValue, 'Value');
      expect(sheet.cellAt(1, 0)?.displayValue, 'inline');
      expect(sheet.cellAt(1, 1)?.displayValue, 'Inline text');
    });

    test('05 boolean', () {
      final sheet = readWorkbook('05_boolean.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 1)?.displayValue, 'TRUE');
      expect(sheet.cellAt(2, 1)?.displayValue, 'FALSE');
    });

    test('06 formula cached value', () {
      final sheet = readWorkbook('06_formula_cached.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 0)?.displayValue, '10');
      expect(sheet.cellAt(1, 1)?.displayValue, '20');
      expect(sheet.cellAt(1, 2)?.displayValue, '30');
    });

    test('07 merged cells', () {
      final sheet = readWorkbook('07_merged_cells.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, 'Customer Info');
      expect(sheet.cellAt(0, 1)?.displayValue, '');
      expect(sheet.cellAt(0, 2)?.displayValue, '');
      expect(sheet.cellAt(1, 0)?.displayValue, 'Name');
      expect(sheet.cellAt(2, 0)?.displayValue, 'Sample User');
    });

    test('08 date number', () {
      final sheet = readWorkbook('08_date_number.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 0)?.displayValue, isNotEmpty);
      expect(sheet.cellAt(2, 0)?.displayValue, isNotEmpty);
    });

    test('09 unicode and special text', () {
      final sheet = readWorkbook('09_unicode_special_text.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 1)?.displayValue, 'Unicode sample: café');
      expect(sheet.cellAt(2, 1)?.displayValue, 'A&B <test> "quote"');
      expect(sheet.cellAt(3, 1)?.displayValue, contains('First line'));
      expect(sheet.cellAt(3, 1)?.displayValue, contains('Second line'));
      expect(sheet.cellAt(4, 1)?.displayValue, '📦✅');
    });

    test('10 sparse large position', () {
      final sheet = readWorkbook('10_sparse_large_position.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, 'Start');
      expect(sheet.cellAt(0, 25)?.displayValue, 'Column 26');
      expect(sheet.cellAt(0, 26)?.displayValue, 'Column 27');
      expect(sheet.cellAt(99, 0)?.displayValue, 'Row 100');
      expect(sheet.cellAt(99, 27)?.displayValue, 'Far position');
    });

    test('11 error cells', () {
      final sheet = readWorkbook('11_error_cells.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 0)?.displayValue, '#DIV/0!');
      expect(sheet.cellAt(1, 0)?.type, ExcelCellType.error);
      expect(sheet.cellAt(2, 0)?.displayValue, '#N/A');
      expect(sheet.cellAt(2, 0)?.type, ExcelCellType.error);
    });

    test('12 rich text shared string', () {
      final sheet = readWorkbook('12_rich_text_shared_string.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, 'Hello World');
    });

    test('13 text number', () {
      final sheet = readWorkbook('13_text_number.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 1)?.displayValue, '00123');
      expect(sheet.cellAt(1, 1)?.type, ExcelCellType.string);
      expect(sheet.cellAt(2, 1)?.displayValue, '00000000000');
      expect(sheet.cellAt(2, 1)?.type, ExcelCellType.string);
    });
  });
}
