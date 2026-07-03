import 'dart:convert';
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
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
    final dot = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('sheet-tab-dot-0')),
    );
    expect((dot.decoration as BoxDecoration).color, Colors.black);
  });

  testWidgets('previews csv bytes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(
          source: PreviewSource.bytes(
            Uint8List.fromList(utf8.encode('Code,Value\n00123,Sample')),
            fileName: 'sample.csv',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('00123'), findsOneWidget);
    expect(find.text('Sample'), findsOneWidget);
  });

  testWidgets('previews docx bytes by file extension', (tester) async {
    final bytes = File(
      'test/fixtures/docx/docx_01_simple_paragraph.docx',
    ).readAsBytesSync();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilePreviewView(
            source: PreviewSource.bytes(bytes, fileName: 'sample.docx'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Welcome to Northwind Library.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('previews docx bytes by mime type', (tester) async {
    final bytes = File(
      'test/fixtures/docx/docx_01_simple_paragraph.docx',
    ).readAsBytesSync();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilePreviewView(
            source: PreviewSource.bytes(
              bytes,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Welcome to Northwind Library.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('updates an explicitly provided theme', (tester) async {
    final bytes = File('test/fixtures/xlsx/01_simple.xlsx').readAsBytesSync();
    final source = PreviewSource.bytes(bytes, fileName: 'simple.xlsx');
    ThemeData pluginTheme(Color primary) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
      ).copyWith(primary: primary),
      useMaterial3: true,
    );
    Color? dotColor() {
      final dot = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('sheet-tab-dot-0')),
      );
      return (dot.decoration as BoxDecoration).color;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(source: source, theme: pluginTheme(Colors.green)),
      ),
    );
    await tester.pumpAndSettle();
    expect(dotColor(), Colors.green);

    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(source: source, theme: pluginTheme(Colors.blue)),
      ),
    );
    await tester.pumpAndSettle();
    expect(dotColor(), Colors.blue);
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

  testWidgets('uses texts resolved from the locale', (tester) async {
    const texts = FilePreviewKitTexts.zhHans();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('zh'),
            child: FilePreviewView(
              source: PreviewSource.bytes(Uint8List(0), fileName: 'notes.txt'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(texts.unsupportedFileTitle), findsOneWidget);
    expect(find.text(texts.unsupportedFileMessage), findsOneWidget);
  });

  testWidgets('uses explicitly provided texts', (tester) async {
    const texts = FilePreviewKitTexts(
      previewFailedTitle: 'Could not open preview',
      unableToPreviewMessage: 'Preview is unavailable.',
      unsupportedFileTitle: 'Unknown format',
      unsupportedFileMessage: 'Choose a supported sample file.',
      noSheetsFound: 'No sample sheets',
      emptySheet: 'Sample sheet is empty',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(
          source: PreviewSource.bytes(Uint8List(0), fileName: 'notes.txt'),
          texts: texts,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(texts.unsupportedFileTitle), findsOneWidget);
    expect(find.text(texts.unsupportedFileMessage), findsOneWidget);
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

  testWidgets('shows a readable docx preview error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FilePreviewView(
          source: PreviewSource.bytes(
            Uint8List.fromList('broken'.codeUnits),
            fileName: 'broken.docx',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview failed'), findsOneWidget);
    expect(find.text('Invalid or corrupted docx file'), findsOneWidget);
  });
}
