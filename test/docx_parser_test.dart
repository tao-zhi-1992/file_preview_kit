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
    expect(run.style.fontSize, closeTo(21.3333, 0.001));
    expect(run.style.color, 0xFFFF0000);
    expect(run.style.highlightColor, 0xFFFFFF00);
  });

  test('parses built-in style kinds for Title, Subtitle, Heading, Normal', () {
    DocxParagraph parseParagraph(String styleVal) {
      return parser
              .parseBytes(
                _documentBytes(
                  '<w:p><w:pPr><w:pStyle w:val="$styleVal"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>',
                ),
              )
              .blocks
              .single
          as DocxParagraph;
    }

    expect(parseParagraph('Title').style.kind, DocxBuiltinKind.title);
    expect(parseParagraph('Subtitle').style.kind, DocxBuiltinKind.subtitle);
    expect(parseParagraph('heading1').style.kind, DocxBuiltinKind.heading1);
    expect(parseParagraph('Heading 2').style.kind, DocxBuiltinKind.heading2);
    expect(parseParagraph('heading_3').style.kind, DocxBuiltinKind.heading3);
    expect(parseParagraph('Normal').style.kind, DocxBuiltinKind.normal);
    expect(parseParagraph('UnknownStyle').style.kind, DocxBuiltinKind.none);
    expect(
      (parser
                  .parseBytes(
                    _documentBytes('<w:p><w:r><w:t>No style</w:t></w:r></w:p>'),
                  )
                  .blocks
                  .single
              as DocxParagraph)
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
    expect(lists.map((list) => list.marker), ['1.', '2.', '3.']);
  });

  test('formats Chinese counting list markers from numbering metadata', () {
    final paragraphs = List.generate(
      11,
      (index) =>
          '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>Heading ${index + 1}</w:t></w:r></w:p>',
    ).join();
    final document = parser.parseBytes(
      _documentBytes(
        paragraphs,
        extraParts: {
          'word/numbering.xml':
              '''<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="chineseCounting"/><w:lvlText w:val="%1、"/></w:lvl></w:abstractNum><w:num w:numId="7"><w:abstractNumId w:val="1"/></w:num></w:numbering>''',
        },
      ),
    );
    final markers = document.blocks.cast<DocxParagraph>().map(
      (paragraph) => paragraph.list!.marker,
    );

    expect(markers, [
      '一、',
      '二、',
      '三、',
      '四、',
      '五、',
      '六、',
      '七、',
      '八、',
      '九、',
      '十、',
      '十一、',
    ]);
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

  test('ignores missing and explicitly disabled numbering definitions', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="9"/></w:numPr></w:pPr><w:r><w:t>Missing definition</w:t></w:r></w:p>'
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr></w:pPr><w:r><w:t>Disabled numbering</w:t></w:r></w:p>',
      ),
    );

    expect(
      document.blocks.whereType<DocxParagraph>().map(
        (paragraph) => paragraph.list,
      ),
      everyElement(isNull),
    );
  });

  test('keeps an unavailable image block when media cannot be resolved', () {
    final document = parser.parseBytes(
      _documentBytes('<w:p><w:r>$_drawing</w:r></w:p>'),
    );
    final image = document.blocks.single as DocxImage;

    expect(image.bytes, isEmpty);
    expect(image.contentType, 'application/octet-stream');
  });

  test('keeps an unsupported chart block with its original dimensions', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:t>Before</w:t></w:r></w:p>'
        '<w:p><w:r>$_chartDrawing</w:r></w:p>'
        '<w:p><w:r><w:t>After</w:t></w:r></w:p>',
      ),
    );

    expect(document.blocks, hasLength(3));
    final chart = document.blocks[1] as DocxUnsupportedContent;
    expect(chart.feature, 'Chart');
    expect(chart.width, 200);
    expect(chart.height, 100);
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
    final paragraph = document.blocks.single as DocxParagraph;
    expect(paragraph.runs, hasLength(3));
    expect(paragraph.runs[1].href, 'https://example.com');
    expect(paragraph.runs[1].anchor, isNull);
    expect(paragraph.runs[1].text, 'Example');
    expect(_paragraphText(paragraph), 'Visit Example site');
  });

  test('parses hyperlink with anchor (bookmark)', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:hyperlink w:anchor="_Toc123"><w:r><w:t>Jump to toc</w:t></w:r></w:hyperlink></w:p>',
      ),
    );
    final hyperlink = (document.blocks.single as DocxParagraph).runs.single;
    expect(hyperlink.href, isNull);
    expect(hyperlink.anchor, '_Toc123');
    expect(hyperlink.text, 'Jump to toc');
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
    expect((document.blocks[1] as DocxBreak).breakType, DocxBreakType.page);
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
    expect((document.blocks[0] as DocxBreak).breakType, DocxBreakType.column);
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
    expect(
      paragraph.runs[0].style.verticalAlignment,
      DocxVerticalAlignment.superscript,
    );
    expect(
      paragraph.runs[1].style.verticalAlignment,
      DocxVerticalAlignment.subscript,
    );
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
        '<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Ignored</w:t></w:r></w:p></w:tc></w:tr>'
        '<w:tr><w:tc><w:p><w:r><w:t>Alone</w:t></w:r></w:p></w:tc></w:tr>'
        '</w:tbl>',
      ),
    );
    final table = document.blocks.single as DocxTable;
    // vMerge cells are skipped; only restart and standalone cells remain.
    expect(table.rows[0].cells.single.rowSpan, 2);
    expect(
      table.rows[0].cells.single.blocks
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

  test('keeps table style identifiers and names', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:tbl><w:tblPr><w:tblStyle w:val="DataTable"/></w:tblPr><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
        stylesXml:
            '''<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="table" w:styleId="DataTable"><w:name w:val="Fictional Data Table"/></w:style></w:styles>''',
      ),
    );
    final table = document.blocks.single as DocxTable;

    expect(table.styleId, 'DataTable');
    expect(table.styleName, 'Fictional Data Table');
  });

  test('parses legacy image data and alternative text', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:pict><v:shape xmlns:v="urn:schemas-microsoft-com:vml"><v:imagedata r:id="legacyImage" o:title="Fictional chart" xmlns:o="urn:schemas-microsoft-com:office:office"/></v:shape></w:pict></w:r></w:p>',
        relationships:
            '''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="legacyImage" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/legacy.png"/></Relationships>''',
        extraFiles: {
          'word/media/legacy.png': [137, 80, 78, 71],
        },
      ),
    );
    final image = document.blocks.single as DocxImage;

    expect(image.bytes, [137, 80, 78, 71]);
    expect(image.contentType, 'image/png');
    expect(image.altText, 'Fictional chart');
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

  test('finds the main document and related parts from relationships', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:t>Relationship document</w:t></w:r></w:p>',
        documentPath: 'custom/main.xml',
        packageRelationships: '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/main.xml"/></Relationships>''',
      ),
    );

    expect(_paragraphText(document.blocks.single), 'Relationship document');
  });

  test('parses paragraph metadata and inherited run formatting', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:pStyle w:val="Notice"/><w:ind w:start="300" w:end="150" w:firstLine="120"/></w:pPr><w:r><w:t>Inherited</w:t></w:r><w:r><w:rPr><w:b w:val="false"/></w:rPr><w:t> override</w:t></w:r></w:p>',
        stylesXml: '''<?xml version="1.0" encoding="UTF-8"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Notice"><w:name w:val="Heading 2"/><w:pPr><w:jc w:val="center"/></w:pPr><w:rPr><w:b/><w:color w:val="336699"/></w:rPr></w:style></w:styles>''',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;

    expect(paragraph.style.styleName, 'Heading 2');
    expect(paragraph.style.kind, DocxBuiltinKind.heading2);
    expect(paragraph.style.align, DocxParagraphAlignment.center);
    expect(paragraph.style.indentStart, 20);
    expect(paragraph.style.indentEnd, 10);
    expect(paragraph.style.firstLineIndent, 8);
    expect(paragraph.runs.first.style.bold, isTrue);
    expect(paragraph.runs.first.style.color, 0xFF336699);
    expect(paragraph.runs.last.style.bold, isFalse);
  });

  test('resolves default and based-on font properties in logical pixels', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:pStyle w:val="DerivedParagraph"/></w:pPr><w:r><w:t>Inherited font</w:t></w:r><w:r><w:rPr><w:rStyle w:val="DerivedCharacter"/><w:b w:val="false"/></w:rPr><w:t> override</w:t></w:r></w:p>',
        stylesXml:
            '''<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/><w:rFonts w:eastAsia="Fictional Sans"/></w:rPr></w:rPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:styleId="BaseParagraph"><w:rPr><w:sz w:val="30"/><w:b/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="DerivedParagraph"><w:basedOn w:val="BaseParagraph"/></w:style>
<w:style w:type="character" w:styleId="BaseCharacter"><w:rPr><w:i/></w:rPr></w:style>
<w:style w:type="character" w:styleId="DerivedCharacter"><w:basedOn w:val="BaseCharacter"/></w:style>
</w:styles>''',
      ),
    );
    final runs = (document.blocks.single as DocxParagraph).runs;

    expect(runs.first.style.fontSize, 20);
    expect(runs.first.style.fontFamily, 'Fictional Sans');
    expect(runs.first.style.bold, isTrue);
    expect(runs.last.style.italic, isTrue);
    expect(runs.last.style.bold, isFalse);
  });

  test('distinguishes exact and minimum paragraph line spacing', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:spacing w:line="360" w:lineRule="exact"/></w:pPr><w:r><w:t>Exact spacing</w:t></w:r></w:p>'
        '<w:p><w:pPr><w:spacing w:line="100" w:lineRule="atLeast"/></w:pPr><w:r><w:t>Minimum spacing</w:t></w:r></w:p>',
      ),
    );
    final exact = (document.blocks.first as DocxParagraph).style;
    final minimum = (document.blocks.last as DocxParagraph).style;

    expect(exact.lineHeight, isNull);
    expect(exact.lineSpacing, 24);
    expect(exact.lineSpacingAtLeast, isFalse);
    expect(minimum.lineSpacing, closeTo(6.667, 0.001));
    expect(minimum.lineSpacingAtLeast, isTrue);
  });

  test('parses list indentation from numbering levels', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>Nested item</w:t></w:r></w:p>',
        extraParts: {
          'word/numbering.xml':
              '''<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="3"><w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/><w:pPr><w:ind w:start="1440" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:num w:numId="7"><w:abstractNumId w:val="3"/></w:num></w:numbering>''',
        },
      ),
    );
    final list = (document.blocks.single as DocxParagraph).list!;

    expect(list.indentStart, 96);
    expect(list.hangingIndent, 24);
  });

  test('parses complex field hyperlinks and form checkboxes', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://example.test/guide" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Guide</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>'
        '<w:p><w:r><w:fldChar w:fldCharType="begin"><w:ffData><w:checkBox><w:checked w:val="1"/></w:checkBox></w:ffData></w:fldChar></w:r><w:r><w:instrText> FORMCHECKBOX </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>',
      ),
    );
    final hyperlink = (document.blocks[0] as DocxParagraph).runs.single;

    expect(hyperlink.text, 'Guide');
    expect(hyperlink.href, 'https://example.test/guide');
    expect(_paragraphText(document.blocks[1]), '☑');
  });

  test('parses structured checkboxes bookmarks and fallback content', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:bookmarkStart w:name="section-one"/><w:sdt><w:sdtPr><w14:checkbox xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr><w:sdtContent><w:r><w:t>☐ task</w:t></w:r></w:sdtContent></w:sdt><mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:Choice Requires="x"><w:r><w:t>Unsupported</w:t></w:r></mc:Choice><mc:Fallback><w:r><w:t> fallback</w:t></w:r></mc:Fallback></mc:AlternateContent></w:p>',
      ),
    );
    final paragraph = document.blocks.single as DocxParagraph;

    expect(paragraph.runs.first.anchor, 'section-one');
    expect(_paragraphText(paragraph), '☑ task fallback');
  });

  test('ignores deleted runs and deleted table rows', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:del><w:r><w:t>Removed</w:t></w:r></w:del><w:ins><w:r><w:t>Kept</w:t></w:r></w:ins></w:p>'
        '<w:tbl><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:t>Removed row</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>Kept row</w:t></w:r></w:p></w:tc></w:tr></w:tbl>',
      ),
    );

    expect(_paragraphText(document.blocks.first), 'Kept');
    final table = document.blocks.last as DocxTable;
    expect(table.rows, hasLength(1));
    expect(_cellText(table.rows.single.cells.single), 'Kept row');
  });

  test('joins content across a deleted paragraph boundary', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>Before </w:t></w:r></w:p><w:p><w:r><w:t>after</w:t></w:r></w:p>',
      ),
    );

    expect(document.blocks, hasLength(1));
    expect(_paragraphText(document.blocks.single), 'Before after');
  });

  test('parses numbering inherited from a paragraph style', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:pStyle w:val="LetterList"/></w:pPr><w:r><w:t>Styled item</w:t></w:r></w:p>',
        extraParts: {
          'word/numbering.xml':
              '''<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="4"><w:lvl w:ilvl="0"><w:start w:val="3"/><w:numFmt w:val="lowerLetter"/><w:pStyle w:val="LetterList"/></w:lvl></w:abstractNum><w:num w:numId="8"><w:abstractNumId w:val="4"/></w:num></w:numbering>''',
        },
      ),
    );
    final list = (document.blocks.single as DocxParagraph).list!;

    expect(list.type, DocxListType.numbered);
    expect(list.number, 3);
    expect(list.marker, '3.');
  });

  test('resolves linked numbering styles and start overrides', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="5"/></w:numPr></w:pPr><w:r><w:t>Overridden item</w:t></w:r></w:p>',
        stylesXml:
            '''<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="numbering" w:styleId="LinkedList"><w:pPr><w:numPr><w:numId w:val="10"/></w:numPr></w:pPr></w:style></w:styles>''',
        extraParts: {
          'word/numbering.xml':
              '''<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="1"><w:numStyleLink w:val="LinkedList"/></w:abstractNum><w:abstractNum w:abstractNumId="2"><w:lvl w:ilvl="0"><w:start w:val="2"/><w:numFmt w:val="decimal"/></w:lvl></w:abstractNum><w:num w:numId="10"><w:abstractNumId w:val="2"/></w:num><w:num w:numId="5"><w:abstractNumId w:val="1"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="7"/></w:lvlOverride></w:num></w:numbering>''',
        },
      ),
    );
    final list = (document.blocks.single as DocxParagraph).list!;

    expect(list.type, DocxListType.numbered);
    expect(list.number, 7);
  });

  test('extracts footnotes endnotes and comments with references', () {
    final relationships = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="footnotes" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/><Relationship Id="endnotes" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes" Target="endnotes.xml"/><Relationship Id="comments" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/></Relationships>''';
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:t>Text</w:t><w:footnoteReference w:id="2"/><w:endnoteReference w:id="3"/><w:commentReference w:id="4"/></w:r></w:p>',
        relationships: relationships,
        extraParts: {
          'word/footnotes.xml':
              '<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:type="separator" w:id="-1"/><w:footnote w:id="2"><w:p><w:r><w:t>Footnote text</w:t></w:r></w:p></w:footnote></w:footnotes>',
          'word/endnotes.xml':
              '<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:endnote w:id="3"><w:p><w:r><w:t>Endnote text</w:t></w:r></w:p></w:endnote></w:endnotes>',
          'word/comments.xml':
              '<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="4" w:author="Fictional Reviewer" w:initials="FR"><w:p><w:r><w:t>Comment text</w:t></w:r></w:p></w:comment></w:comments>',
        },
      ),
    );

    expect(_paragraphText(document.blocks.single), 'Text[1][2][1]');
    expect(document.notes, hasLength(2));
    expect(document.notes.first.type, DocxNoteType.footnote);
    expect(_paragraphText(document.notes.first.blocks.single), 'Footnote text');
    expect(document.comments.single.authorName, 'Fictional Reviewer');
    expect(
      _paragraphText(document.comments.single.blocks.single),
      'Comment text',
    );
  });

  test('extracts text box content without creating a broken image', () {
    final document = parser.parseBytes(
      _documentBytes(
        '<w:p><w:r><w:t>Body</w:t><w:drawing><w:txbxContent><w:p><w:r><w:t>Text box</w:t></w:r></w:p></w:txbxContent></w:drawing></w:r></w:p>',
      ),
    );

    expect(document.blocks.whereType<DocxImage>(), isEmpty);
    expect(document.blocks.map(_paragraphText), ['Body', 'Text box']);
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

Uint8List _documentBytes(
  String body, {
  String? relationships,
  String? stylesXml,
  String documentPath = 'word/document.xml',
  String? packageRelationships,
  Map<String, String> extraParts = const {},
  Map<String, List<int>> extraFiles = const {},
}) {
  final xml = utf8.encode(
    '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><w:body>$body</w:body></w:document>''',
  );
  final archive = Archive()
    ..addFile(ArchiveFile(documentPath, xml.length, xml));

  if (relationships != null) {
    final bytes = utf8.encode(relationships);
    archive.addFile(
      ArchiveFile(_relationshipsPath(documentPath), bytes.length, bytes),
    );
  }

  if (stylesXml != null) {
    final bytes = utf8.encode(stylesXml);
    archive.addFile(ArchiveFile('word/styles.xml', bytes.length, bytes));
  }

  if (packageRelationships != null) {
    final bytes = utf8.encode(packageRelationships);
    archive.addFile(ArchiveFile('_rels/.rels', bytes.length, bytes));
  }

  for (final entry in extraParts.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  for (final entry in extraFiles.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _relationshipsPath(String path) {
  final slash = path.lastIndexOf('/');
  final directory = slash < 0 ? '' : path.substring(0, slash + 1);
  final filename = slash < 0 ? path : path.substring(slash + 1);
  return '${directory}_rels/$filename.rels';
}

const _drawing =
    '''<w:drawing><wp:inline><wp:extent cx="952500" cy="476250"/><a:graphic><a:graphicData><a:blip r:embed="missing"/></a:graphicData></a:graphic></wp:inline></w:drawing>''';

const _chartDrawing =
    '''<w:drawing><wp:inline><wp:extent cx="1905000" cy="952500"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" r:id="chart1"/></a:graphicData></a:graphic></wp:inline></w:drawing>''';
