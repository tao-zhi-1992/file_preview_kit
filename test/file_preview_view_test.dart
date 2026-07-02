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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Sample User A'), findsOneWidget);
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
    expect(find.text('This file format is not supported yet.'), findsOneWidget);
  });

  testWidgets('shows a readable preview error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(
          source: PreviewSource.bytes(
            Uint8List.fromList('broken'.codeUnits),
            fileName: 'broken.xlsx',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview failed'), findsOneWidget);
    expect(find.text('Invalid or corrupted xlsx file'), findsOneWidget);
  });
}
