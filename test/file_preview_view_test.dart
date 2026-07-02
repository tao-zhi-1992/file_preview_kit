import 'dart:io';
import 'dart:typed_data';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('previews xlsx bytes', (tester) async {
    final bytes = File('test/fixtures/xlsx/01_simple.xlsx').readAsBytesSync();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilePreviewView(
            source: PreviewSource.bytes(bytes, fileName: 'simple.xlsx'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
  });

  testWidgets('shows unsupported file type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(
          source: PreviewSource.bytes(Uint8List(0), fileName: 'notes.txt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unsupported file type'), findsOneWidget);
  });
}
