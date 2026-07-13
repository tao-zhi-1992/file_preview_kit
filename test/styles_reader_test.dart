import 'package:file_preview_kit/src/excel/models/excel_cell_alignment.dart';
import 'package:file_preview_kit/src/excel/models/excel_cell_style.dart';
import 'package:file_preview_kit/src/excel/parser/styles_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reader = StylesReader();

  test('resolves font and fill styles from cellXfs', () {
    final result = reader.parse('''
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
''');

    expect(result.styles, hasLength(2));
    expect(result.styles[0].bold, isFalse);
    expect(result.styles[0].fontSize, 11);
    expect(result.styles[1].bold, isTrue);
    expect(result.styles[1].italic, isTrue);
    expect(result.styles[1].fontSize, 14);
    expect(result.styles[1].fontColor, const Color(0xFFFF0000));
    expect(result.styles[1].backgroundColor, const Color(0xFFFFFF00));
  });

  test('parses alignment, wrap, borders, and font extras', () {
    final result = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font>
      <u/>
      <strike/>
      <name val="Calibri"/>
    </font>
  </fonts>
  <fills count="1"><fill/></fills>
  <borders count="2">
    <border/>
    <border>
      <left style="thin"><color rgb="FF0000FF"/></left>
      <right style="thin"><color rgb="FF0000FF"/></right>
      <top style="thin"><color rgb="FF0000FF"/></top>
      <bottom style="thin"><color rgb="FF0000FF"/></bottom>
    </border>
  </borders>
  <cellXfs count="1">
    <xf fontId="0" fillId="0" borderId="1" numFmtId="14">
      <alignment horizontal="center" vertical="top" wrapText="1"/>
    </xf>
  </cellXfs>
</styleSheet>
''');

    final style = result.styles.single;
    expect(style.horizontalAlign, ExcelHorizontalAlign.center);
    expect(style.verticalAlign, ExcelVerticalAlign.top);
    expect(style.wrapText, isTrue);
    expect(style.underline, isTrue);
    expect(style.strikethrough, isTrue);
    expect(style.fontFamily, 'Calibri');
    expect(style.borders.left?.color, const Color(0xFF0000FF));
    expect(style.borders.left?.width, 0.5);
    expect(result.numberFormats.single, 'm/d/yy');
  });

  test('parses center-across-selection alignment', () {
    final result = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font/></fonts>
  <fills count="1"><fill/></fills>
  <borders count="1"><border/></borders>
  <cellXfs count="1">
    <xf fontId="0" fillId="0" borderId="0">
      <alignment horizontal="centerContinuous"/>
    </xf>
  </cellXfs>
</styleSheet>
''');

    expect(
      result.styles.single.horizontalAlign,
      ExcelHorizontalAlign.centerContinuous,
    );
  });

  test('ignores cellStyleXfs and only parses cellXfs entries', () {
    final result = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font><b/><sz val="12"/></font>
  </fonts>
  <fills count="1">
    <fill><patternFill patternType="none"/></fill>
  </fills>
  <cellStyleXfs count="1">
    <xf fontId="0" fillId="0"/>
  </cellStyleXfs>
  <cellXfs count="1">
    <xf fontId="0" fillId="0"/>
  </cellXfs>
</styleSheet>
''');

    expect(result.styles, hasLength(1));
    expect(result.styles.single.bold, isTrue);
    expect(result.styles.single.fontSize, 12);
  });

  test('returns empty result when cellXfs is missing', () {
    final result = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font/></fonts>
  <fills count="1"><fill/></fills>
</styleSheet>
''');

    expect(result.styles, isEmpty);
    expect(result.numberFormats, isEmpty);
  });

  test('ignores invalid rgb color values', () {
    final result = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font><color rgb="FF00"/></font>
  </fonts>
  <fills count="1">
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="1234"/>
      </patternFill>
    </fill>
  </fills>
  <cellXfs count="1">
    <xf fontId="0" fillId="0"/>
  </cellXfs>
</styleSheet>
''');

    expect(result.styles.single.fontColor, isNull);
    expect(result.styles.single.backgroundColor, isNull);
  });
}
