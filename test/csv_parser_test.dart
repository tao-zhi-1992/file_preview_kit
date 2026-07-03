import 'dart:convert';
import 'dart:typed_data';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses UTF-8 CSV and normalizes rows', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        '\ufeffCode,Description,Value\r\n00123,"Sample, item",10\r\n00007,"Line one\nLine two"',
      ),
    );
    final sheet = CsvParser().parseBytes(bytes).firstSheet!;

    expect(sheet.rowCount, 3);
    expect(sheet.columnCount, 3);
    expect(sheet.cellAt(1, 0)?.displayValue, '00123');
    expect(sheet.cellAt(1, 1)?.displayValue, 'Sample, item');
    expect(sheet.cellAt(2, 1)?.displayValue, 'Line one\nLine two');
    expect(sheet.cellAt(2, 2)?.type, ExcelCellType.blank);
    expect(sheet.cellAt(2, 2)?.address, 'C3');
  });

  test('rejects empty CSV bytes', () {
    expect(
      () => CsvParser().parseBytes(Uint8List(0)),
      throwsA(isA<EmptyFileException>()),
    );
  });

  test('rejects invalid UTF-8 CSV bytes', () {
    expect(
      () => CsvParser().parseBytes(Uint8List.fromList([0xff])),
      throwsA(isA<InvalidCsvException>()),
    );
  });
}
