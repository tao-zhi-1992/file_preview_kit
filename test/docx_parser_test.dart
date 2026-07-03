import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = DocxParser();

  test('parses a simple text document', () {
    final document = parser.parseBytes(
      _fixture('docx_01_simple_paragraph.docx'),
    );
    final paragraph = document.blocks.single as DocxParagraph;

    expect(paragraph.runs.single.text, 'Welcome to Northwind Library.');
  });

  test('keeps multiple and empty paragraphs in source order', () {
    final document = parser.parseBytes(
      _fixture('docx_02_multiple_paragraphs.docx'),
    );

    expect(document.blocks, hasLength(3));
    expect(
      (document.blocks[0] as DocxParagraph).runs.single.text,
      'First project paragraph.',
    );
    expect((document.blocks[1] as DocxParagraph).runs, isEmpty);
    expect(
      (document.blocks[2] as DocxParagraph).runs.single.text,
      'Final project paragraph.',
    );
  });

  test('parses direct text formatting', () {
    final document = parser.parseBytes(_fixture('docx_03_rich_text_runs.docx'));
    final paragraph = document.blocks.single as DocxParagraph;

    expect(paragraph.runs[0].style.bold, isTrue);
    expect(paragraph.runs[2].style.italic, isTrue);
    expect(paragraph.runs[4].style.underline, isTrue);
  });

  test('parses line breaks and tabs', () {
    final document = parser.parseBytes(
      _fixture('docx_04_line_break_and_tab.docx'),
    );
    final paragraph = document.blocks.single as DocxParagraph;

    expect(
      paragraph.runs.single.text,
      'First line\nSecond line\tIndented value',
    );
  });

  test('decodes mixed Unicode text without replacement characters', () {
    final document = parser.parseBytes(_fixture('docx_05_unicode_text.docx'));
    final text = (document.blocks.single as DocxParagraph).runs.single.text;

    expect(text.codeUnits, containsAll(<int>[20013, 25991]));
    expect(text, isNot(contains('\uFFFD')));
  });

  test('keeps heading style identifiers', () {
    final document = parser.parseBytes(_fixture('docx_06_headings.docx'));

    expect((document.blocks[0] as DocxParagraph).style.styleId, 'Heading1');
    expect((document.blocks[1] as DocxParagraph).style.styleId, 'Heading2');
    expect((document.blocks[2] as DocxParagraph).style.styleId, isNull);
    expect(
      (document.blocks[0] as DocxParagraph).style.kind,
      DocxBuiltinKind.heading1,
    );
    expect(
      (document.blocks[1] as DocxParagraph).style.kind,
      DocxBuiltinKind.heading2,
    );
    expect(
      (document.blocks[2] as DocxParagraph).style.kind,
      DocxBuiltinKind.none,
    );
  });

  test('parses readability paragraph and text styles', () {
    final document = parser.parseBytes(
      _documentBytes(
        '''
<w:p><w:pPr><w:pStyle w:val="Title"/><w:jc w:val="right"/><w:spacing w:before="240" w:after="120" w:line="360"/></w:pPr><w:r><w:rPr><w:strike/><w:sz w:val="32"/><w:color w:val="FF0000"/><w:highlight w:val="yellow"/></w:rPr><w:t>Priority note</w:t></w:r></w:p>''',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;
    final run = paragraph.runs.single;

    expect(paragraph.style.styleId, 'Title');
    expect(paragraph.style.kind, DocxBuiltinKind.title);
    expect(paragraph.style.align, DocxParagraphAlignment.right);
    expect(paragraph.style.spacingBefore, 16);
    expect(paragraph.style.spacingAfter, 8);
    expect(paragraph.style.lineHeight, 1.5);
    expect(run.style.strike, isTrue);
    expect(run.style.fontSize, 16);
    expect(run.style.color, 0xFFFF0000);
    expect(run.style.highlightColor, 0xFFFFFF00);
  });

  test('parses built-in style kinds for Title, Subtitle, Heading, Normal', () {
    DocxParagraph _parseParagraph(String styleVal) {
      return parser.parseBytes(
        _documentBytes(
          '<w:p><w:pPr><w:pStyle w:val="$styleVal"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>',
        ),
      ).blocks.single as DocxParagraph;
    }

    expect(_parseParagraph('Title').style.kind, DocxBuiltinKind.title);
    expect(_parseParagraph('Subtitle').style.kind, DocxBuiltinKind.subtitle);
    expect(_parseParagraph('heading1').style.kind, DocxBuiltinKind.heading1);
    expect(_parseParagraph('Heading 2').style.kind, DocxBuiltinKind.heading2);
    expect(_parseParagraph('heading_3').style.kind, DocxBuiltinKind.heading3);
    expect(_parseParagraph('Normal').style.kind, DocxBuiltinKind.normal);
    expect(_parseParagraph('UnknownStyle').style.kind, DocxBuiltinKind.none);
    expect(
      (parser
              .parseBytes(
                _documentBytes('<w:p><w:r><w:t>No style</w:t></w:r></w:p>'),
              )
              .blocks
              .single as DocxParagraph)
          .style
          .kind,
      DocxBuiltinKind.none,
    );
  });

  test('parses bullet list types and levels', () {
    final document = parser.parseBytes(_fixture('docx_07_bullet_list.docx'));
    final lists = document.blocks
        .cast<DocxParagraph>()
        .map((paragraph) => paragraph.list!)
        .toList();

    expect(lists.map((list) => list.type), everyElement(DocxListType.bullet));
    expect(lists.map((list) => list.level), [0, 1, 0]);
    expect(lists.map((list) => list.number), everyElement(isNull));
  });

  test('parses continuous decimal list numbers', () {
    final document = parser.parseBytes(_fixture('docx_08_numbered_list.docx'));
    final lists = document.blocks
        .cast<DocxParagraph>()
        .map((paragraph) => paragraph.list!)
        .toList();

    expect(lists.map((list) => list.type), everyElement(DocxListType.numbered));
    expect(lists.map((list) => list.number), [1, 2, 3]);
  });

  test('parses a basic table', () {
    final document = parser.parseBytes(_fixture('docx_09_basic_table.docx'));
    final table = document.blocks.single as DocxTable;

    expect(table.rows, hasLength(3));
    expect(table.rows.first.cells, hasLength(3));
    expect(_cellText(table.rows[1].cells[0]), 'A-101');
    expect(_cellText(table.rows[2].cells[2]), 'Draft');
  });

  test('parses table borders widths and horizontal spans', () {
    final document = parser.parseBytes(
      _documentBytes(
        '''
<w:tbl><w:tblPr><w:tblBorders><w:top w:val="single"/></w:tblBorders></w:tblPr><w:tblGrid><w:gridCol w:w="1500"/><w:gridCol w:w="3000"/></w:tblGrid><w:tr><w:tc><w:tcPr><w:tcW w:w="4500" w:type="dxa"/><w:gridSpan w:val="2"/></w:tcPr><w:p><w:r><w:t>Merged heading</w:t></w:r></w:p></w:tc></w:tr></w:tbl>''',
      ),
    );
    final table = document.blocks.single as DocxTable;
    final cell = table.rows.single.cells.single;

    expect(table.hasBorders, isTrue);
    expect(table.columnWidths, [100, 200]);
    expect(cell.columnSpan, 2);
    expect(cell.width, 300);
  });

  test('keeps multiple paragraphs in a table cell', () {
    final document = parser.parseBytes(
      _fixture('docx_10_table_multiline_cell.docx'),
    );
    final table = document.blocks.single as DocxTable;
    final blocks = table.rows.single.cells.first.blocks;

    expect(blocks, hasLength(2));
    expect(
      (blocks[0] as DocxParagraph).runs.single.text,
      'First cell paragraph',
    );
    expect(
      (blocks[1] as DocxParagraph).runs.single.text,
      'Second cell paragraph',
    );
  });

  test('keeps inline image and text blocks in source order', () {
    final document = parser.parseBytes(_fixture('docx_11_image_inline.docx'));

    expect(document.blocks, hasLength(3));
    expect(_paragraphText(document.blocks[0]), 'Before sample image');
    final image = document.blocks[1] as DocxImage;
    expect(image.bytes, isNotEmpty);
    expect(image.contentType, 'image/png');
    expect(image.width, 100);
    expect(image.height, 50);
    expect(_paragraphText(document.blocks[2]), 'After sample image');
  });

  test('parses all mixed document content including a table image', () {
    final document = parser.parseBytes(_fixture('docx_12_mixed_document.docx'));
    final table = document.blocks.whereType<DocxTable>().single;

    expect((document.blocks.first as DocxParagraph).style.styleId, 'Heading1');
    expect(
      document.blocks.whereType<DocxParagraph>().where(
        (paragraph) => paragraph.list != null,
      ),
      hasLength(6),
    );
    expect(table.rows[2].cells[2].blocks.single, isA<DocxImage>());
    expect(document.blocks.whereType<DocxImage>(), hasLength(1));
    expect(
      _paragraphText(document.blocks.last),
      'End of sample preview document.',
    );
  });

  test('falls back to a bullet when numbering metadata is missing', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="9"/></w:numPr></w:pPr><w:r><w:t>Fallback item</w:t></w:r></w:p>',
      ),
    );
    final list = (document.blocks.single as DocxParagraph).list!;

    expect(list.type, DocxListType.bullet);
    expect(list.number, isNull);
  });

  test('keeps an unavailable image block when media cannot be resolved', () {
    final document = parser.parseBytes(
      _documentBytes('<w:p><w:r>$_drawing</w:r></w:p>'),
    );
    final image = document.blocks.single as DocxImage;

    expect(image.bytes, isEmpty);
    expect(image.contentType, 'application/octet-stream');
  });

  test('keeps image metadata when the related media file is missing', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r>$_drawing</w:r></w:p>',
        relationships: '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="missing" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/missing.png"/></Relationships>''',
      ),
    );
    final image = document.blocks.single as DocxImage;

    expect(image.bytes, isEmpty);
    expect(image.contentType, 'image/png');
  });
}

Uint8List _fixture(String name) {
  return File('test/fixtures/docx/$name').readAsBytesSync();
}

String _cellText(DocxTableCell cell) {
  return cell.blocks
      .whereType<DocxParagraph>()
      .expand((paragraph) => paragraph.runs)
      .map((run) => run.text)
      .join();
}

String _paragraphText(DocxBlock block) {
  return (block as DocxParagraph).runs.map((run) => run.text).join();
}

Uint8List _documentBytes(String body, {String? relationships}) {
  final xml = utf8.encode(
    '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><w:body>$body</w:body></w:document>''',
  );
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', xml.length, xml));

  if (relationships != null) {
    final bytes = utf8.encode(relationships);
    archive.addFile(
      ArchiveFile('word/_rels/document.xml.rels', bytes.length, bytes),
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

const _drawing =
    '''<w:drawing><wp:inline><wp:extent cx="952500" cy="476250"/><a:graphic><a:graphicData><a:blip r:embed="missing"/></a:graphicData></a:graphic></wp:inline></w:drawing>''';
