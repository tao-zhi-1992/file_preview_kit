import 'dart:io';
import 'dart:typed_data';

import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders paragraph formatting and alignment', (tester) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          alignment: DocxParagraphAlignment.center,
          spacingBefore: 12,
          spacingAfter: 6,
          lineHeight: 2,
          runs: [
            DocxTextRun(text: 'Bold', bold: true),
            DocxTextRun(text: ' Italic', italic: true),
            DocxTextRun(text: ' Underlined', underline: true),
            DocxTextRun(
              text: ' Priority',
              strike: true,
              fontSize: 18,
              color: 0xFFFF0000,
              highlightColor: 0xFFFFFF00,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final root = richText.text as TextSpan;
    final children = root.children!.cast<TextSpan>();

    expect(richText.textAlign, TextAlign.center);
    expect(children[0].style!.fontWeight, FontWeight.bold);
    expect(children[1].style!.fontStyle, FontStyle.italic);
    expect(children[2].style!.decoration, TextDecoration.underline);
    expect(children[3].style!.decoration, TextDecoration.lineThrough);
    expect(children[3].style!.fontSize, 18);
    expect(children[3].style!.color, const Color(0xFFFF0000));
    expect(children[3].style!.backgroundColor, const Color(0xFFFFFF00));
    expect(root.style!.height, 2);
    final padding = tester.widget<Padding>(find.byType(Padding).first);
    expect(padding.padding, const EdgeInsets.only(top: 12, bottom: 6));
  });

  testWidgets('renders mixed paragraphs and a table', (tester) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(runs: [DocxTextRun(text: 'Before table')]),
        DocxTable(
          rows: [
            DocxTableRow(
              cells: [
                DocxTableCell(
                  blocks: [
                    DocxParagraph(runs: [DocxTextRun(text: 'Cell value')]),
                  ],
                ),
              ],
            ),
          ],
        ),
        DocxParagraph(runs: [DocxTextRun(text: 'After table')]),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    expect(find.byKey(const ValueKey('docx-table-cell-0-0')), findsOneWidget);
    expect(find.text('Before table', findRichText: true), findsOneWidget);
    expect(find.text('Cell value', findRichText: true), findsOneWidget);
    expect(find.text('After table', findRichText: true), findsOneWidget);
  });

  testWidgets('renders headings with readable fallback styles', (tester) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          styleId: 'Title',
          runs: [DocxTextRun(text: 'Document title')],
        ),
        DocxParagraph(
          styleId: 'Subtitle',
          runs: [DocxTextRun(text: 'Document subtitle')],
        ),
        DocxParagraph(
          styleId: 'Heading1',
          runs: [DocxTextRun(text: 'Primary heading')],
        ),
        DocxParagraph(
          styleId: 'Heading2',
          runs: [DocxTextRun(text: 'Secondary heading')],
        ),
        DocxParagraph(
          styleId: 'Heading3',
          runs: [DocxTextRun(text: 'Tertiary heading')],
        ),
        DocxParagraph(runs: [DocxTextRun(text: 'Ordinary text')]),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    final spans = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text as TextSpan)
        .toList();
    expect(spans[0].style!.fontSize, 26);
    expect(spans[0].style!.fontWeight, FontWeight.bold);
    expect(spans[1].style!.fontSize, 18);
    expect(spans[1].style!.fontStyle, FontStyle.italic);
    expect(spans[2].style!.fontSize, 22);
    expect(spans[3].style!.fontSize, 20);
    expect(spans[4].style!.fontSize, 18);
    expect(spans[5].style!.fontSize, 16);
  });

  testWidgets('renders bullet and numbered list markers', (tester) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          list: DocxListInfo(type: DocxListType.bullet, level: 1),
          runs: [DocxTextRun(text: 'Nested item')],
        ),
        DocxParagraph(
          list: DocxListInfo(type: DocxListType.numbered, level: 0, number: 3),
          runs: [DocxTextRun(text: 'Third item')],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    expect(find.text('◦ Nested item', findRichText: true), findsOneWidget);
    expect(find.text('3. Third item', findRichText: true), findsOneWidget);
    final paragraphPadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.text('◦ Nested item', findRichText: true),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect((paragraphPadding.padding as EdgeInsets).left, 24);
  });

  testWidgets('renders table borders widths and horizontal spans', (
    tester,
  ) async {
    const document = DocxDocument(
      blocks: [
        DocxTable(
          hasBorders: true,
          columnWidths: [100, 200],
          rows: [
            DocxTableRow(
              cells: [
                DocxTableCell(
                  columnSpan: 2,
                  blocks: [
                    DocxParagraph(runs: [DocxTextRun(text: 'Merged heading')]),
                  ],
                ),
              ],
            ),
            DocxTableRow(
              cells: [
                DocxTableCell(
                  blocks: [
                    DocxParagraph(runs: [DocxTextRun(text: 'Narrow cell')]),
                  ],
                ),
                DocxTableCell(
                  blocks: [
                    DocxParagraph(runs: [DocxTextRun(text: 'Wide cell')]),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    expect(find.byKey(const ValueKey('docx-table-cell-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('docx-table-cell-0-1')), findsNothing);
    final firstCell = tester.widget<Container>(
      find.byKey(const ValueKey('docx-table-cell-1-0')),
    );
    final secondCell = tester.widget<Container>(
      find.byKey(const ValueKey('docx-table-cell-1-1')),
    );
    expect(
      ((firstCell.decoration as BoxDecoration).border as Border).top.width,
      1,
    );
    final firstFlex = tester.widget<Expanded>(
      find.ancestor(
        of: find.byKey(const ValueKey('docx-table-cell-1-0')),
        matching: find.byType(Expanded),
      ),
    );
    final secondFlex = tester.widget<Expanded>(
      find.ancestor(
        of: find.byKey(const ValueKey('docx-table-cell-1-1')),
        matching: find.byType(Expanded),
      ),
    );
    expect(secondFlex.flex, firstFlex.flex * 2);
    expect(secondCell.padding, const EdgeInsets.all(8));
  });

  testWidgets('renders a supported image from document bytes', (tester) async {
    final bytes = File(
      'test/fixtures/docx/docx_11_image_inline.docx',
    ).readAsBytesSync();
    final document = DocxParser().parseBytes(bytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('docx-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('docx-image-unavailable')), findsNothing);
  });

  testWidgets('renders a placeholder for an unavailable image', (tester) async {
    final document = DocxDocument(
      blocks: [
        DocxImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/gif',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    expect(
      find.byKey(const ValueKey('docx-image-unavailable')),
      findsOneWidget,
    );
  });
}
