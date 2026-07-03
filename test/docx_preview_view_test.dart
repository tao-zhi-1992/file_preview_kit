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
          style: DocxParagraphStyle(
            align: DocxParagraphAlignment.center,
            spacingBefore: 12,
            spacingAfter: 6,
            lineHeight: 2,
          ),
          runs: [
            DocxTextRun(text: 'Bold', style: DocxTextStyle(bold: true)),
            DocxTextRun(text: ' Italic', style: DocxTextStyle(italic: true)),
            DocxTextRun(
              text: ' Underlined',
              style: DocxTextStyle(underline: true),
            ),
            DocxTextRun(
              text: ' Priority',
              style: DocxTextStyle(
                strike: true,
                fontSize: 18,
                color: 0xFFFF0000,
                highlightColor: 0xFFFFFF00,
              ),
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
    final padding = tester
        .widgetList<Padding>(find.byType(Padding))
        .singleWhere((padding) => padding.child is RichText);
    expect(padding.padding, const EdgeInsets.only(top: 12, bottom: 6));
  });

  testWidgets(
    'renders multi-style text with font size color highlight alignment',
    (tester) async {
      const document = DocxDocument(
        blocks: [
          DocxParagraph(
            style: DocxParagraphStyle(
              styleId: 'Title',
              kind: DocxBuiltinKind.title,
              align: DocxParagraphAlignment.center,
              spacingBefore: 20,
              spacingAfter: 10,
              lineHeight: 1.8,
            ),
            runs: [
              DocxTextRun(
                text: 'Styled Document',
                style: DocxTextStyle(
                  bold: true,
                  fontSize: 28,
                  color: 0xFF1A237E,
                ),
              ),
            ],
          ),
          DocxParagraph(
            style: DocxParagraphStyle(
              align: DocxParagraphAlignment.right,
              spacingBefore: 8,
              spacingAfter: 4,
            ),
            runs: [
              DocxTextRun(
                text: 'Italic and ',
                style: DocxTextStyle(italic: true),
              ),
              DocxTextRun(
                text: 'underlined ',
                style: DocxTextStyle(underline: true),
              ),
              DocxTextRun(
                text: 'strikethrough',
                style: DocxTextStyle(strike: true),
              ),
            ],
          ),
          DocxParagraph(
            runs: [
              DocxTextRun(
                text: 'Highlighted text',
                style: DocxTextStyle(highlightColor: 0xFFFFFF00, fontSize: 20),
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

      // Title: center alignment, bold, large font, custom color
      final titleRichText = tester
          .widgetList<RichText>(find.byType(RichText))
          .first;
      expect(titleRichText.textAlign, TextAlign.center);
      final titleSpan = titleRichText.text as TextSpan;
      expect(titleSpan.style!.fontWeight, FontWeight.bold);
      expect(titleSpan.style!.fontSize, closeTo(37.3333, 0.001));
      expect(titleSpan.children!.single.style!.color, const Color(0xFF1A237E));
      expect(titleSpan.children!.single.style!.fontSize, 28);

      // First paragraph padding
      final paddings = tester
          .widgetList<Padding>(find.byType(Padding))
          .where((padding) => padding.child is RichText)
          .toList();
      expect(
        paddings[0].padding,
        const EdgeInsets.only(left: 0, top: 20, bottom: 10),
      );

      // Italic, underline, strikethrough in second paragraph
      final secondRichText = tester
          .widgetList<RichText>(find.byType(RichText))
          .toList()[1];
      expect(secondRichText.textAlign, TextAlign.right);
      final secondChildren = (secondRichText.text as TextSpan).children!
          .cast<TextSpan>();
      expect(secondChildren[0].style!.fontStyle, FontStyle.italic);
      expect(secondChildren[1].style!.decoration, TextDecoration.underline);
      expect(secondChildren[2].style!.decoration, TextDecoration.lineThrough);

      // Highlighted text with custom font size
      final thirdChildren =
          (tester.widgetList<RichText>(find.byType(RichText)).toList()[2].text
                  as TextSpan)
              .children!
              .cast<TextSpan>();
      expect(
        thirdChildren.single.style!.backgroundColor,
        const Color(0xFFFFFF00),
      );
    },
  );

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
          style: DocxParagraphStyle(
            styleId: 'Title',
            kind: DocxBuiltinKind.title,
          ),
          runs: [DocxTextRun(text: 'Document title')],
        ),
        DocxParagraph(
          style: DocxParagraphStyle(
            styleId: 'Subtitle',
            kind: DocxBuiltinKind.subtitle,
          ),
          runs: [DocxTextRun(text: 'Document subtitle')],
        ),
        DocxParagraph(
          style: DocxParagraphStyle(
            styleId: 'Heading1',
            kind: DocxBuiltinKind.heading1,
          ),
          runs: [DocxTextRun(text: 'Primary heading')],
        ),
        DocxParagraph(
          style: DocxParagraphStyle(
            styleId: 'Heading2',
            kind: DocxBuiltinKind.heading2,
          ),
          runs: [DocxTextRun(text: 'Secondary heading')],
        ),
        DocxParagraph(
          style: DocxParagraphStyle(
            styleId: 'Heading3',
            kind: DocxBuiltinKind.heading3,
          ),
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
    expect(spans[0].style!.fontSize, closeTo(37.3333, 0.001));
    expect(spans[0].style!.fontWeight, FontWeight.bold);
    expect(spans[1].style!.fontSize, 16);
    expect(spans[1].style!.fontStyle, FontStyle.italic);
    expect(spans[2].style!.fontSize, closeTo(21.3333, 0.001));
    expect(spans[3].style!.fontSize, closeTo(17.3333, 0.001));
    expect(spans[4].style!.fontSize, 16);
    expect(spans[5].style!.fontSize, closeTo(14.6667, 0.001));
  });

  testWidgets('keeps minimum line spacing above the natural line height', (
    tester,
  ) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          style: DocxParagraphStyle(
            lineSpacing: 6.6667,
            lineSpacingAtLeast: true,
          ),
          runs: [
            DocxTextRun(
              text: 'First line\nSecond line',
              style: DocxTextStyle(fontSize: 20),
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

    final text = tester.widget<RichText>(find.byType(RichText));
    expect((text.text as TextSpan).style!.height, 1.15);
  });

  testWidgets('renders bullet and numbered list markers', (tester) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          list: DocxListInfo(type: DocxListType.bullet, level: 1),
          runs: [DocxTextRun(text: 'Nested item')],
        ),
        DocxParagraph(
          list: DocxListInfo(
            type: DocxListType.numbered,
            level: 0,
            number: 10,
            marker: '十、',
          ),
          runs: [
            DocxTextRun(
              text: 'Tenth item',
              style: DocxTextStyle(color: 0xFF365F91),
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

    expect(find.text('◦'), findsOneWidget);
    expect(find.text('Nested item', findRichText: true), findsOneWidget);
    expect(find.text('十、'), findsOneWidget);
    expect(find.text('Tenth item', findRichText: true), findsOneWidget);
    final marker = tester.widget<Text>(find.text('十、'));
    expect(marker.softWrap, isFalse);
    expect(marker.style!.color, const Color(0xFF365F91));
    expect(find.byType(SizedBox), findsWidgets);
    final paragraphPadding = tester
        .widgetList<Padding>(find.byType(Padding))
        .firstWhere((padding) => padding.child is Row);
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
          contentType: 'image/tiff',
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

  testWidgets('opens inline links and applies paragraph indentation', (
    tester,
  ) async {
    final opened = <String>[];
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          style: DocxParagraphStyle(indentStart: 20, indentEnd: 10),
          runs: [
            DocxTextRun(text: 'Read '),
            DocxTextRun(text: 'Example', href: 'https://example.test/guide'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocxPreviewView(document: document, onLinkTap: opened.add),
        ),
      ),
    );
    await tester.tap(find.text('Example'));

    expect(opened, ['https://example.test/guide']);
    final padding = tester
        .widgetList<Padding>(find.byType(Padding))
        .singleWhere((padding) => padding.child is RichText);
    expect(
      padding.padding,
      const EdgeInsets.only(left: 20, right: 10, bottom: 8),
    );
  });

  testWidgets('renders extracted notes and comments', (tester) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(runs: [DocxTextRun(text: 'Document text')]),
      ],
      notes: [
        DocxNote(
          id: '2',
          type: DocxNoteType.footnote,
          blocks: [
            DocxParagraph(runs: [DocxTextRun(text: 'Footnote text')]),
          ],
        ),
      ],
      comments: [
        DocxComment(
          id: '4',
          authorName: 'Fictional Reviewer',
          authorInitials: 'FR',
          blocks: [
            DocxParagraph(runs: [DocxTextRun(text: 'Comment text')]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Footnote text', findRichText: true), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('FR 1.'), findsOneWidget);
    expect(find.text('Comment text', findRichText: true), findsOneWidget);
  });

  testWidgets('applies first-line and hanging list indentation', (
    tester,
  ) async {
    const document = DocxDocument(
      blocks: [
        DocxParagraph(
          style: DocxParagraphStyle(indentStart: 20, firstLineIndent: 16),
          runs: [DocxTextRun(text: 'Indented paragraph')],
        ),
        DocxParagraph(
          list: DocxListInfo(
            type: DocxListType.bullet,
            level: 0,
            indentStart: 72,
            hangingIndent: 24,
          ),
          runs: [DocxTextRun(text: 'Hanging list item')],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DocxPreviewView(document: document)),
      ),
    );

    final firstLine = tester.widget<RichText>(find.byType(RichText).first);
    final prefix = (firstLine.text as TextSpan).children!.first as WidgetSpan;
    expect((prefix.child as SizedBox).width, 16);
    final listPadding = tester
        .widgetList<Padding>(find.byType(Padding))
        .firstWhere((padding) => padding.child is Row);
    expect((listPadding.padding as EdgeInsets).left, 48);
  });
}
