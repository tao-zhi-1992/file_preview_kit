import 'package:file_preview_kit/src/excel/parser/excel_number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExcelNumberFormat', () {
    test('formats built-in date format', () {
      expect(
        ExcelNumberFormat.format('45292', 'm/d/yy'),
        '1/1/24',
      );
    });

    test('formats built-in percent format', () {
      expect(
        ExcelNumberFormat.format('0.25', '0%'),
        '25%',
      );
      expect(
        ExcelNumberFormat.format('0.125', '0.00%'),
        '12.50%',
      );
    });

    test('formats decimal and integer formats', () {
      expect(
        ExcelNumberFormat.format('100.5', '0.00'),
        '100.50',
      );
      expect(
        ExcelNumberFormat.format('1234', '#,##0'),
        '1,234',
      );
    });

    test('keeps raw value for text and general formats', () {
      expect(ExcelNumberFormat.format('00123', '@'), '00123');
      expect(ExcelNumberFormat.format('42', 'General'), '42');
      expect(ExcelNumberFormat.format('abc', '0.00'), 'abc');
    });

    test('resolves built-in format ids', () {
      expect(
        ExcelNumberFormat.resolveFormatCode(14, const {}),
        'm/d/yy',
      );
      expect(
        ExcelNumberFormat.resolveFormatCode(165, {165: '0.000'}),
        '0.000',
      );
    });
  });
}
