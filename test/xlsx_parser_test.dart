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

      expect(sheet.cellAt(0, 0)?.displayValue, '姓名');
      expect(sheet.cellAt(1, 0)?.displayValue, '张三');
      expect(sheet.cellAt(1, 1)?.displayValue, '18');
      expect(sheet.cellAt(1, 2)?.displayValue, '100.5');
    });

    test('02 multi sheet', () {
      final workbook = readWorkbook('02_multi_sheet.xlsx');

      expect(workbook.sheets.length, 2);
      expect(workbook.sheets[0].name, '库存表');
      expect(workbook.sheets[1].name, '客户表');
      expect(workbook.sheets[0].cellAt(1, 0)?.displayValue, '苹果');
      expect(workbook.sheets[1].cellAt(1, 0)?.displayValue, '湖南银濎');
    });

    test('03 empty cells', () {
      final sheet = readWorkbook('03_empty_cells.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, '姓名');
      expect(sheet.cellAt(0, 1)?.displayValue, '');
      expect(sheet.cellAt(0, 2)?.displayValue, '年龄');
      expect(sheet.cellAt(1, 0)?.displayValue, '');
      expect(sheet.cellAt(1, 1)?.displayValue, '');
      expect(sheet.cellAt(1, 2)?.displayValue, '');
      expect(sheet.cellAt(2, 0)?.displayValue, '张三');
      expect(sheet.cellAt(2, 2)?.displayValue, '18');
    });

    test('04 inline string', () {
      final sheet = readWorkbook('04_inline_string.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, '类型');
      expect(sheet.cellAt(0, 1)?.displayValue, '值');
      expect(sheet.cellAt(1, 0)?.displayValue, 'inline');
      expect(sheet.cellAt(1, 1)?.displayValue, '内联字符串');
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

      expect(sheet.cellAt(0, 0)?.displayValue, '客户信息');
      expect(sheet.cellAt(0, 1)?.displayValue, '');
      expect(sheet.cellAt(0, 2)?.displayValue, '');
      expect(sheet.cellAt(1, 0)?.displayValue, '姓名');
      expect(sheet.cellAt(2, 0)?.displayValue, '张三');
    });

    test('08 date number', () {
      final sheet = readWorkbook('08_date_number.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 0)?.displayValue, isNotEmpty);
      expect(sheet.cellAt(2, 0)?.displayValue, isNotEmpty);
    });

    test('09 chinese and special text', () {
      final sheet = readWorkbook('09_chinese_special_text.xlsx').firstSheet!;

      expect(sheet.cellAt(1, 1)?.displayValue, '湖南银濎企业发展有限公司');
      expect(sheet.cellAt(2, 1)?.displayValue, 'A&B <测试> "引号"');
      expect(sheet.cellAt(3, 1)?.displayValue, contains('第一行'));
      expect(sheet.cellAt(3, 1)?.displayValue, contains('第二行'));
      expect(sheet.cellAt(4, 1)?.displayValue, '📦✅');
    });

    test('10 sparse large position', () {
      final sheet = readWorkbook('10_sparse_large_position.xlsx').firstSheet!;

      expect(sheet.cellAt(0, 0)?.displayValue, '起点');
      expect(sheet.cellAt(0, 25)?.displayValue, '第26列');
      expect(sheet.cellAt(0, 26)?.displayValue, '第27列');
      expect(sheet.cellAt(99, 0)?.displayValue, '第100行');
      expect(sheet.cellAt(99, 27)?.displayValue, '远位置');
    });
  });
}
