import 'package:file_preview_kit/src/excel/models/excel_cell_style.dart';
import 'package:file_preview_kit/src/excel/parser/styles_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reader = StylesReader();

  test('resolves font and fill styles from cellXfs', () {
    final styles = reader.parse('''
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

    expect(styles, hasLength(2));
    expect(styles[0].bold, isFalse);
    expect(styles[0].italic, isFalse);
    expect(styles[0].fontSize, 11);
    expect(styles[0].fontColor, isNull);
    expect(styles[0].backgroundColor, isNull);
    expect(styles[1].bold, isTrue);
    expect(styles[1].italic, isTrue);
    expect(styles[1].fontSize, 14);
    expect(styles[1].fontColor, const Color(0xFFFF0000));
    expect(styles[1].backgroundColor, const Color(0xFFFFFF00));
  });

  test('ignores cellStyleXfs and only parses cellXfs entries', () {
    final styles = reader.parse('''
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

    expect(styles, hasLength(1));
    expect(styles.single.bold, isTrue);
    expect(styles.single.fontSize, 12);
  });

  test('returns empty list when cellXfs is missing', () {
    final styles = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font/></fonts>
  <fills count="1"><fill/></fills>
</styleSheet>
''');

    expect(styles, isEmpty);
  });

  test('ignores invalid rgb color values', () {
    final styles = reader.parse('''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1">
    <font>
      <color rgb="FF00"/>
      <color rgb="AUTO"/>
    </font>
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

    expect(styles.single.fontColor, isNull);
    expect(styles.single.backgroundColor, isNull);
  });
}
