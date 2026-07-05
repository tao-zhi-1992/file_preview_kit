import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilePreviewLoader.detectType', () {
    test('detects xlsx by file extension', () {
      expect(
        FilePreviewLoader.detectType(
          PreviewSource.bytes(Uint8List(0), fileName: 'report.xlsx'),
        ),
        PreviewType.xlsx,
      );
    });

    test('detects csv by file extension', () {
      expect(
        FilePreviewLoader.detectType(
          PreviewSource.bytes(Uint8List(0), fileName: 'data.csv'),
        ),
        PreviewType.csv,
      );
    });

    test('detects docx by file extension', () {
      expect(
        FilePreviewLoader.detectType(
          PreviewSource.bytes(Uint8List(0), fileName: 'notes.docx'),
        ),
        PreviewType.docx,
      );
    });

    test('detects xlsx by mime type', () {
      expect(
        FilePreviewLoader.detectType(
          PreviewSource.bytes(
            Uint8List(0),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
        PreviewType.xlsx,
      );
    });

    test('detects csv by mime type', () {
      expect(
        FilePreviewLoader.detectType(
          PreviewSource.bytes(Uint8List(0), mimeType: 'text/csv'),
        ),
        PreviewType.csv,
      );
    });

    test('detects docx by mime type', () {
      expect(
        FilePreviewLoader.detectType(
          PreviewSource.bytes(
            Uint8List(0),
            mimeType:
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ),
        ),
        PreviewType.docx,
      );
    });

    test('returns unsupported for unknown input', () {
      expect(
        FilePreviewLoader.detectType(PreviewSource.bytes(Uint8List(0))),
        PreviewType.unsupported,
      );
    });
  });

  group('FilePreviewLoader.load', () {
    test('loads xlsx workbook content', () async {
      final bytes = File('test/fixtures/xlsx/01_simple.xlsx').readAsBytesSync();
      final content = await FilePreviewLoader.load(
        PreviewSource.bytes(bytes, fileName: 'simple.xlsx'),
      );

      expect(content, isA<XlsxPreviewContent>());
      final workbook = (content as XlsxPreviewContent).workbook;
      expect(workbook.sheets, isNotEmpty);
    });

    test('loads csv workbook content', () async {
      final content = await FilePreviewLoader.load(
        PreviewSource.bytes(
          Uint8List.fromList(utf8.encode('Code,Value\n00123,Sample')),
          fileName: 'sample.csv',
        ),
      );

      expect(content, isA<CsvPreviewContent>());
      final workbook = (content as CsvPreviewContent).workbook;
      expect(workbook.firstSheet?.cellAt(1, 0)?.displayValue, '00123');
    });

    test('loads docx document content', () async {
      final bytes = File(
        'test/fixtures/docx/docx_01_simple_paragraph.docx',
      ).readAsBytesSync();
      final content = await FilePreviewLoader.load(
        PreviewSource.bytes(bytes, fileName: 'sample.docx'),
      );

      expect(content, isA<DocxPreviewContent>());
    });

    test('returns unsupported content for unknown input', () async {
      final content = await FilePreviewLoader.load(
        PreviewSource.bytes(Uint8List.fromList([1, 2, 3])),
      );

      expect(content, isA<UnsupportedPreviewContent>());
    });
  });
}
