import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List workbookBytes({required String sheetXml, String? stylesXml}) {
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
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheetXml));

    if (stylesXml != null) {
      archive.addFile(ArchiveFile.string('xl/styles.xml', stylesXml));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  group('XlsxParser extended features', () {
    test('formats numeric cells using numFmt', () {
      final workbook = XlsxParser().parseBytes(
        workbookBytes(
          stylesXml: '''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <cellXfs count="2">
    <xf numFmtId="0"/>
    <xf numFmtId="14"/>
  </cellXfs>
</styleSheet>
''',
          sheetXml: '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" s="1" t="n"><v>45292</v></c>
      <c r="B1" s="0" t="n"><v>0.25</v></c>
    </row>
  </sheetData>
</worksheet>
''',
        ),
      );

      expect(workbook.firstSheet!.cellAt(0, 0)?.displayValue, '1/1/24');
      expect(workbook.firstSheet!.cellAt(0, 1)?.displayValue, '0.25');
    });

    test('parses column widths and merge regions', () {
      final workbook = XlsxParser().parseBytes(
        workbookBytes(
          sheetXml: '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews><sheetView showGridLines="0"/></sheetViews>
  <cols>
    <col min="2" max="2" width="20" customWidth="1"/>
  </cols>
  <sheetData>
    <row r="1"><c r="A1" t="s"><v>Title</v></c></row>
  </sheetData>
  <mergeCells count="1">
    <mergeCell ref="A1:C1"/>
  </mergeCells>
</worksheet>
''',
        ),
      );

      final sheet = workbook.firstSheet!;
      expect(sheet.columnWidths[1], 145);
      expect(sheet.mergeRegions, hasLength(1));
      expect(sheet.mergeRegions.single.startRow, 0);
      expect(sheet.mergeRegions.single.endColumn, 2);
      expect(sheet.isMergeCovered(0, 1), isTrue);
      expect(sheet.isMergeCovered(0, 0), isFalse);
      expect(sheet.showGridLines, isFalse);
    });
  });
}
