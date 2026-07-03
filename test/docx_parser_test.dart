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

  test('parses hyperlink inside paragraph', () {
    final document = parser.parseBytes(
      _documentBytes(
        '''
<w:p><w:r><w:t>Visit </w:t></w:r><w:hyperlink r:id="rLink1"><w:r><w:rPr><w:rStyle w:val="Hyperlink"/><w:u w:val="single"/></w:rPr><w:t>Example</w:t></w:r></w:hyperlink><w:r><w:t> site</w:t></w:r></w:p>''',
        relationships: '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rLink1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com"/></Relationships>''',
      ),
    );
    // The hyperlink is emitted as a separate block between two paragraphs.
    expect(document.blocks, hasLength(3));
    expect(document.blocks[1], isA<DocxHyperlink>());
    final hyperlink = document.blocks[1] as DocxHyperlink;
    expect(hyperlink.href, 'https://example.com');
    expect(hyperlink.anchor, isNull);
    expect(hyperlink.runs.single.text, 'Example');
    expect(
      _paragraphText(document.blocks[0]),
      'Visit ',
    );
    expect(_paragraphText(document.blocks[2]), ' site');
  });

  test('parses hyperlink with anchor (bookmark)', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:hyperlink w:anchor="_Toc123"><w:r><w:t>Jump to toc</w:t></w:r></w:hyperlink></w:p>',
      ),
    );
    final hyperlink = document.blocks.single as DocxHyperlink;
    expect(hyperlink.href, isNull);
    expect(hyperlink.anchor, '_Toc123');
    expect(hyperlink.runs.single.text, 'Jump to toc');
  });

  test('parses page break', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:t>Before</w:t></w:r></w:p><w:p><w:r><w:br w:type="page"/></w:r></w:p><w:p><w:r><w:t>After</w:t></w:r></w:p>',
      ),
    );
    // The page-break paragraph produces a DocxBreak between two paragraphs.
    expect(document.blocks, hasLength(3));
    expect(document.blocks[1], isA<DocxBreak>());
    expect(
      (document.blocks[1] as DocxBreak).breakType,
      DocxBreakType.page,
    );
  });

  test('parses column break', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:br w:type="column"/><w:t>After column break</w:t></w:r></w:p>',
      ),
    );
    // column-break block followed by paragraph
    expect(document.blocks, hasLength(2));
    expect(document.blocks[0], isA<DocxBreak>());
    expect(
      (document.blocks[0] as DocxBreak).breakType,
      DocxBreakType.column,
    );
  });

  test('parses no-break hyphen and soft hyphen', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:t>Non</w:t></w:r><w:r><w:noBreakHyphen /></w:r><w:r><w:t>breaking</w:t></w:r><w:r><w:softHyphen /></w:r><w:r><w:t>soft</w:t></w:r></w:p>',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;
    expect(
      paragraph.runs.map((r) => r.text).join(),
      'Non\u2011breaking\u00ADsoft',
    );
  });

  test('parses symbol character', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:sym w:font="Symbol" w:char="B0"/><w:t> symbol</w:t></w:r></w:p>',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;
    expect(paragraph.runs[0].text, '♠ symbol');
  });

  test('parses allCaps and smallCaps run properties', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:rPr><w:caps/><w:rFonts w:ascii="Arial"/></w:rPr><w:t>UPPER</w:t></w:r><w:r><w:rPr><w:smallCaps/></w:rPr><w:t>small</w:t></w:r></w:p>',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;
    expect(paragraph.runs[0].style.allCaps, isTrue);
    expect(paragraph.runs[0].style.fontFamily, 'Arial');
    expect(paragraph.runs[1].style.smallCaps, isTrue);
  });

  test('parses vertical alignment (superscript / subscript)', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:t>sup</w:t></w:r><w:r><w:rPr><w:vertAlign w:val="subscript"/></w:rPr><w:t>sub</w:t></w:r></w:p>',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;
    expect(paragraph.runs[0].style.verticalAlignment, DocxVerticalAlignment.superscript);
    expect(paragraph.runs[1].style.verticalAlignment, DocxVerticalAlignment.subscript);
  });

  test('parses table row header flag', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:tbl><w:tblGrid><w:gridCol w:w="3000"/></w:tblGrid><w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>Header</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>Data</w:t></w:r></w:p></w:tc></w:tr></w:tbl>',
      ),
    );
    final table = document.blocks.single as DocxTable;
    expect(table.rows[0].isHeader, isTrue);
    expect(table.rows[1].isHeader, isFalse);
  });

  test('parses table cell vertical merge', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:tbl><w:tblGrid><w:gridCol w:w="3000"/></w:tblGrid>'
        '<w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Merged</w:t></w:r></w:p></w:tc></w:tr>'
        '<w:tr><w:tc><w:tcPr><w:vMerge w:val="continue"/></w:tcPr><w:p><w:r><w:t>Ignored</w:t></w:r></w:p></w:tc></w:tr>'
        '<w:tr><w:tc><w:p><w:r><w:t>Alone</w:t></w:r></w:p></w:tc></w:tr>'
        '</w:tbl>',
      ),
    );
    final table = document.blocks.single as DocxTable;
    // vMerge cells are skipped; only restart and standalone cells remain.
    expect(table.rows[0].cells.single.rowSpan, greaterThan(1));
    expect(table.rows[0].cells.single.blocks
        .whereType<DocxParagraph>()
        .expand((p) => p.runs)
        .map((r) => r.text)
        .join(),
      'Merged',
    );
    // Second row's cell should be skipped (vMerge=continue).
    expect(table.rows[1].cells, hasLength(0));
    // Third row has a normal cell.
    expect(
      table.rows[2].cells.single.blocks
          .whereType<DocxParagraph>()
          .single
          .runs
          .single
          .text,
      'Alone',
    );
  });

  test('parses styles.xml for paragraph and character style resolution', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:rPr><w:rStyle w:val="Strong"/></w:rPr><w:t>Title</w:t></w:r></w:p>',
        stylesXml: '''<?xml version="1.0" encoding="UTF-8"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:styleId="Heading1">
<w:name w:val="heading 1"/>
<w:rPr><w:b/><w:sz w:val="48"/></w:rPr>
</w:style>
<w:style w:type="character" w:styleId="Strong">
<w:name w:val="Strong"/>
<w:rPr><w:b/><w:i/><w:color w:val="CC0000"/></w:rPr>
</w:style>
</w:styles>''',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;
    expect(paragraph.style.styleId, 'Heading1');
    expect(paragraph.style.kind, DocxBuiltinKind.heading1);
    // Character style properties should be inherited.
    final run = paragraph.runs.single;
    expect(run.style.bold, isTrue);
    expect(run.style.italic, isTrue);
    expect(run.style.color, 0xFFCC0000);
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

Uint8List _documentBytes(String body, {String? relationships, String? stylesXml}) {
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

  if (stylesXml != null) {
    final bytes = utf8.encode(stylesXml);
    archive.addFile(
      ArchiveFile('word/styles.xml', bytes.length, bytes),
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

const _drawing =
    '''<w:drawing><wp:inline><wp:extent cx="952500" cy="476250"/><a:graphic><a:graphicData><a:blip r:embed="missing"/></a:graphicData></a:graphic></wp:inline></w:drawing>''';
