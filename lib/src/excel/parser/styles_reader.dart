import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../models/excel_cell_alignment.dart';
import '../models/excel_cell_borders.dart';
import '../models/excel_cell_style.dart';
import '../models/excel_styles_parse_result.dart';
import 'excel_number_format.dart';
import 'excel_theme_colors.dart';

/// Parses `xl/styles.xml` into cell style records.
class StylesReader {
  /// Creates a styles reader.
  const StylesReader();

  /// Returns styles and number formats per `cellXfs/xf` entry.
  ExcelStylesParseResult parse(
    String xmlText, {
    ExcelThemeColors? themeColors,
  }) {
    final document = XmlDocument.parse(xmlText);

    final numFmts = _parseNumFmts(document);
    final fonts = _parseFonts(document, themeColors);
    final fills = _parseFills(document, themeColors);
    final borders = _parseBorders(document, themeColors);

    final cellXfs = document.findAllElements('cellXfs').firstOrNull;
    if (cellXfs == null) {
      return ExcelStylesParseResult.empty;
    }

    final styles = <ExcelCellStyle>[];
    final numberFormats = <String?>[];

    for (final xf in cellXfs.findElements('xf')) {
      final fontId = int.tryParse(xf.getAttribute('fontId') ?? '');
      final fillId = int.tryParse(xf.getAttribute('fillId') ?? '');
      final borderId = int.tryParse(xf.getAttribute('borderId') ?? '');
      final numFmtId = int.tryParse(xf.getAttribute('numFmtId') ?? '0') ?? 0;

      final fontStyle = fontId != null && fontId >= 0 && fontId < fonts.length
          ? fonts[fontId]
          : ExcelCellStyle.empty;

      final fillColor = fillId != null && fillId >= 0 && fillId < fills.length
          ? fills[fillId]
          : null;

      final borderStyle =
          borderId != null && borderId >= 0 && borderId < borders.length
          ? borders[borderId]
          : ExcelCellBorders.empty;

      final alignment = _parseAlignment(xf);

      styles.add(
        ExcelCellStyle(
          bold: fontStyle.bold,
          italic: fontStyle.italic,
          underline: fontStyle.underline,
          strikethrough: fontStyle.strikethrough,
          fontSize: fontStyle.fontSize,
          fontFamily: fontStyle.fontFamily,
          fontColor: fontStyle.fontColor,
          backgroundColor: fillColor,
          horizontalAlign: alignment.horizontalAlign,
          verticalAlign: alignment.verticalAlign,
          wrapText: alignment.wrapText,
          borders: borderStyle,
        ),
      );
      numberFormats.add(ExcelNumberFormat.resolveFormatCode(numFmtId, numFmts));
    }

    return ExcelStylesParseResult(styles: styles, numberFormats: numberFormats);
  }

  Map<int, String> _parseNumFmts(XmlDocument document) {
    final result = <int, String>{};

    for (final numFmt in document.findAllElements('numFmt')) {
      final id = int.tryParse(numFmt.getAttribute('numFmtId') ?? '');
      final code = numFmt.getAttribute('formatCode');
      if (id != null && code != null) {
        result[id] = code;
      }
    }

    return result;
  }

  List<ExcelCellStyle> _parseFonts(
    XmlDocument document,
    ExcelThemeColors? themeColors,
  ) {
    final fontsElement = document.findAllElements('fonts').firstOrNull;
    if (fontsElement == null) {
      return const [];
    }

    final result = <ExcelCellStyle>[];

    for (final font in fontsElement.findElements('font')) {
      final bold = font.findElements('b').isNotEmpty;
      final italic = font.findElements('i').isNotEmpty;
      final underline = font.findElements('u').isNotEmpty;
      final strikethrough = font.findElements('strike').isNotEmpty;

      final sizeText = font.findElements('sz').isEmpty
          ? null
          : font.findElements('sz').first.getAttribute('val');

      final fontSize = double.tryParse(sizeText ?? '');

      final nameText = font.findElements('name').isEmpty
          ? null
          : font.findElements('name').first.getAttribute('val');

      final colorElement = font.findElements('color').isEmpty
          ? null
          : font.findElements('color').first;

      final fontColor = _parseColor(colorElement, themeColors);

      result.add(
        ExcelCellStyle(
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough,
          fontSize: fontSize,
          fontFamily: nameText,
          fontColor: fontColor,
        ),
      );
    }

    return result;
  }

  List<Color?> _parseFills(
    XmlDocument document,
    ExcelThemeColors? themeColors,
  ) {
    final fillsElement = document.findAllElements('fills').firstOrNull;
    if (fillsElement == null) {
      return const [];
    }

    final result = <Color?>[];

    for (final fill in fillsElement.findElements('fill')) {
      final fgColor = fill.findAllElements('fgColor').isEmpty
          ? null
          : fill.findAllElements('fgColor').first;

      result.add(_parseColor(fgColor, themeColors));
    }

    return result;
  }

  List<ExcelCellBorders> _parseBorders(
    XmlDocument document,
    ExcelThemeColors? themeColors,
  ) {
    final bordersElement = document.findAllElements('borders').firstOrNull;
    if (bordersElement == null) {
      return const [];
    }

    final result = <ExcelCellBorders>[];

    for (final border in bordersElement.findElements('border')) {
      result.add(
        ExcelCellBorders(
          left: _parseBorderSide(
            border.findElements('left').firstOrNull,
            themeColors,
          ),
          right: _parseBorderSide(
            border.findElements('right').firstOrNull,
            themeColors,
          ),
          top: _parseBorderSide(
            border.findElements('top').firstOrNull,
            themeColors,
          ),
          bottom: _parseBorderSide(
            border.findElements('bottom').firstOrNull,
            themeColors,
          ),
        ),
      );
    }

    return result;
  }

  BorderSide? _parseBorderSide(
    XmlElement? element,
    ExcelThemeColors? themeColors,
  ) {
    if (element == null) {
      return null;
    }

    final style = element.getAttribute('style');
    if (style == null || style == 'none') {
      return null;
    }

    final colorElement = element.findElements('color').isEmpty
        ? null
        : element.findElements('color').first;
    final color = _parseColor(colorElement, themeColors) ?? Colors.black;

    return BorderSide(color: color, width: _borderWidth(style));
  }

  double _borderWidth(String style) {
    return switch (style) {
      'hair' => 0.25,
      'thin' => 0.5,
      'medium' => 1,
      'thick' => 1.5,
      'double' => 1,
      _ => 0.5,
    };
  }

  ({
    ExcelHorizontalAlign horizontalAlign,
    ExcelVerticalAlign verticalAlign,
    bool wrapText,
  })
  _parseAlignment(XmlElement xf) {
    final alignment = xf.findElements('alignment').firstOrNull;
    if (alignment == null) {
      return (
        horizontalAlign: ExcelHorizontalAlign.general,
        verticalAlign: ExcelVerticalAlign.bottom,
        wrapText: false,
      );
    }

    final horizontal = switch (alignment.getAttribute('horizontal')) {
      'center' => ExcelHorizontalAlign.center,
      'right' => ExcelHorizontalAlign.right,
      'left' => ExcelHorizontalAlign.left,
      _ => ExcelHorizontalAlign.general,
    };

    final vertical = switch (alignment.getAttribute('vertical')) {
      'center' => ExcelVerticalAlign.center,
      'top' => ExcelVerticalAlign.top,
      _ => ExcelVerticalAlign.bottom,
    };

    final wrapText = alignment.getAttribute('wrapText') == '1';

    return (
      horizontalAlign: horizontal,
      verticalAlign: vertical,
      wrapText: wrapText,
    );
  }

  Color? _parseColor(XmlElement? element, ExcelThemeColors? themeColors) {
    if (element == null) {
      return null;
    }

    final rgb = element.getAttribute('rgb');
    if (rgb != null && rgb.length == 8) {
      final value = int.tryParse(rgb, radix: 16);
      if (value != null) {
        return Color(value);
      }
    }

    final themeIndex = int.tryParse(element.getAttribute('theme') ?? '');
    if (themeIndex != null && themeColors != null) {
      final base = themeColors.colorAt(themeIndex);
      if (base != null) {
        return _applyTint(base, element.getAttribute('tint'));
      }
    }

    final indexed = int.tryParse(element.getAttribute('indexed') ?? '');
    if (indexed != null) {
      return _indexedColor(indexed);
    }

    return null;
  }

  Color? _applyTint(Color color, String? tintText) {
    final tint = double.tryParse(tintText ?? '');
    if (tint == null || tint == 0) {
      return color;
    }

    final hsl = HSLColor.fromColor(color);
    final lightness = tint < 0
        ? hsl.lightness * (1 + tint)
        : hsl.lightness + ((1 - hsl.lightness) * tint);
    return hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
  }

  Color? _indexedColor(int index) {
    const palette = <int, Color>{
      0: Color(0xFF000000),
      1: Color(0xFFFFFFFF),
      2: Color(0xFFFF0000),
      3: Color(0xFF00FF00),
      4: Color(0xFF0000FF),
      5: Color(0xFFFFFF00),
      6: Color(0xFFFF00FF),
      7: Color(0xFF00FFFF),
      8: Color(0xFF000000),
      9: Color(0xFFFFFFFF),
      10: Color(0xFFFF0000),
      22: Color(0xFFC0C0C0),
      23: Color(0xFF808080),
      64: Color(0xFF000000),
    };

    return palette[index];
  }
}
