import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = DocxParser();

  test('throws EmptyFileException for an empty docx file', () {
    expect(
      () => parser.parseBytes(Uint8List(0)),
      throwsA(isA<EmptyFileException>()),
    );
  });

  test('throws InvalidDocxException for corrupted docx bytes', () {
    expect(
      () => parser.parseBytes(Uint8List.fromList(utf8.encode('not a zip'))),
      throwsA(isA<InvalidDocxException>()),
    );
  });

  test('throws InvalidDocxException when document xml is missing', () {
    final content = utf8.encode('<sample/>');
    final archive = Archive()
      ..addFile(ArchiveFile('sample.xml', content.length, content));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    expect(
      () => parser.parseBytes(bytes),
      throwsA(isA<InvalidDocxException>()),
    );
  });
}
