import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List styledWorkbookBytes({
    required String sheetXml,
    required String stylesXml,
  }) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/workbook.xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Styled" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheetXml))
      ..addFile(ArchiveFile.string('xl/styles.xml', stylesXml));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  const stylesXml = '''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/></font>
    <font>
      <b/>
      <i/>
      <sz val="14"/>
      <color rgb="FFFF0000"/>
    </font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FFFFFF00"/>
      </patternFill>
    </fill>
  </fills>
  <cellXfs count="2">
    <xf fontId="0" fillId="0"/>
    <xf fontId="1" fillId="2"/>
  </cellXfs>
</styleSheet>
''';

  group('XlsxParser styles', () {
    test('resolves cell style index from s attribute', () {
      final workbook = XlsxParser().parseBytes(
        styledWorkbookBytes(
          stylesXml: stylesXml,
          sheetXml: '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" s="0"><v>Plain</v></c>
      <c r="B1" s="1"><v>Styled</v></c>
    </row>
  </sheetData>
</worksheet>
''',
        ),
      );

      final sheet = workbook.firstSheet!;
      final plainCell = sheet.cellAt(0, 0)!;
      final styledCell = sheet.cellAt(0, 1)!;

      expect(plainCell.style.bold, isFalse);
      expect(plainCell.style.italic, isFalse);
      expect(plainCell.style.fontSize, 11);
      expect(plainCell.style.fontColor, isNull);
      expect(plainCell.style.backgroundColor, isNull);
      expect(styledCell.style.bold, isTrue);
      expect(styledCell.style.italic, isTrue);
      expect(styledCell.style.fontSize, 14);
      expect(styledCell.style.fontColor, const Color(0xFFFF0000));
      expect(styledCell.style.backgroundColor, const Color(0xFFFFFF00));
    });

    test('keeps background styles on blank cells', () {
      final workbook = XlsxParser().parseBytes(
        styledWorkbookBytes(
          stylesXml: stylesXml,
          sheetXml: '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <cols><col min="2" max="2" style="1"/></cols>
  <sheetData>
    <row r="1" s="1" customFormat="1">
      <c r="A1"/>
      <c r="C1"><v>Sample</v></c>
    </row>
    <row r="2" s="1" customFormat="1"/>
    <row r="3">
      <c r="A3"><v>Sample</v></c>
      <c r="C3"><v>Sample</v></c>
    </row>
  </sheetData>
</worksheet>
''',
        ),
      );

      final sheet = workbook.firstSheet!;
      expect(sheet.cellAt(0, 0)!.displayValue, isEmpty);
      expect(
        sheet.cellAt(0, 0)!.style.backgroundColor,
        const Color(0xFFFFFF00),
      );
      expect(
        sheet.cellAt(0, 1)!.style.backgroundColor,
        const Color(0xFFFFFF00),
      );
      expect(
        sheet.cellAt(1, 1)!.style.backgroundColor,
        const Color(0xFFFFFF00),
      );
      expect(
        sheet.cellAt(2, 1)!.style.backgroundColor,
        const Color(0xFFFFFF00),
      );
    });

    test('uses empty style when styles.xml is missing', () {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'xl/workbook.xml',
            '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'xl/_rels/workbook.xml.rels',
            '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''',
          ),
        )
        ..addFile(
          ArchiveFile.string('xl/worksheets/sheet1.xml', '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1"><c r="A1" s="3"><v>Sample</v></c></row>
  </sheetData>
</worksheet>
'''),
        );

      final workbook = XlsxParser().parseBytes(
        Uint8List.fromList(ZipEncoder().encode(archive)!),
      );

      expect(workbook.firstSheet!.cellAt(0, 0)!.style.bold, isFalse);
      expect(workbook.firstSheet!.cellAt(0, 0)!.style.backgroundColor, isNull);
    });
  });
}
