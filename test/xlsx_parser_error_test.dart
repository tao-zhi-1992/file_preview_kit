import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List zip(Map<String, String> files) {
    final archive = Archive();
    for (final file in files.entries) {
      archive.addFile(ArchiveFile.string(file.key, file.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  group('XlsxParser errors', () {
    test('throws EmptyFileException for an empty file', () {
      final bytes = File('test/fixtures/invalid/empty.xlsx').readAsBytesSync();

      expect(
        () => XlsxParser().parseBytes(bytes),
        throwsA(isA<EmptyFileException>()),
      );
    });

    test('throws InvalidXlsxException for non-xlsx bytes', () {
      final bytes = File(
        'test/fixtures/invalid/not_xlsx.txt',
      ).readAsBytesSync();

      expect(
        () => XlsxParser().parseBytes(bytes),
        throwsA(isA<InvalidXlsxException>()),
      );
    });

    test('throws InvalidXlsxException for a corrupted xlsx file', () {
      final bytes = File(
        'test/fixtures/invalid/corrupted.xlsx',
      ).readAsBytesSync();

      expect(
        () => XlsxParser().parseBytes(bytes),
        throwsA(isA<InvalidXlsxException>()),
      );
    });

    test('throws PasswordProtectedFileException for encrypted content', () {
      final bytes = zip({'EncryptedPackage': 'encrypted'});

      expect(
        () => XlsxParser().parseBytes(bytes),
        throwsA(isA<PasswordProtectedFileException>()),
      );
    });

    test('throws InvalidXlsxException when workbook metadata is missing', () {
      final bytes = zip({
        'xl/worksheets/sheet1.xml': '<worksheet><sheetData/></worksheet>',
      });

      expect(
        () => XlsxParser().parseBytes(bytes),
        throwsA(isA<InvalidXlsxException>()),
      );
    });
  });
}
