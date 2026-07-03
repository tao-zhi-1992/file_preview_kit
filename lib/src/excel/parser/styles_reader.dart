import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../models/excel_cell_style.dart';

/// Parses `xl/styles.xml` into cell style records.
class StylesReader {
  /// Returns one [ExcelCellStyle] per `cellXfs/xf` entry.
  List<ExcelCellStyle> parse(String xmlText) {
    final document = XmlDocument.parse(xmlText);

    final fonts = _parseFonts(document);
    final fills = _parseFills(document);

    final cellXfs = document.findAllElements('cellXfs').firstOrNull;
    if (cellXfs == null) {
      return const [];
    }

    final styles = <ExcelCellStyle>[];

    for (final xf in cellXfs.findElements('xf')) {
      final fontId = int.tryParse(xf.getAttribute('fontId') ?? '');
      final fillId = int.tryParse(xf.getAttribute('fillId') ?? '');

      final fontStyle =
          fontId != null && fontId >= 0 && fontId < fonts.length
              ? fonts[fontId]
              : ExcelCellStyle.empty;

      final fillColor =
          fillId != null && fillId >= 0 && fillId < fills.length
              ? fills[fillId]
              : null;

      styles.add(
        ExcelCellStyle(
          bold: fontStyle.bold,
          italic: fontStyle.italic,
          fontSize: fontStyle.fontSize,
          fontColor: fontStyle.fontColor,
          backgroundColor: fillColor,
        ),
      );
    }

    return styles;
  }

  List<ExcelCellStyle> _parseFonts(XmlDocument document) {
    final fontsElement = document.findAllElements('fonts').firstOrNull;
    if (fontsElement == null) {
      return const [];
    }

    final result = <ExcelCellStyle>[];

    for (final font in fontsElement.findElements('font')) {
      final bold = font.findElements('b').isNotEmpty;
      final italic = font.findElements('i').isNotEmpty;

      final sizeText = font.findElements('sz').isEmpty
          ? null
          : font.findElements('sz').first.getAttribute('val');

      final fontSize = double.tryParse(sizeText ?? '');

      final colorElement = font.findElements('color').isEmpty
          ? null
          : font.findElements('color').first;

      final fontColor = _parseColor(colorElement);

      result.add(
        ExcelCellStyle(
          bold: bold,
          italic: italic,
          fontSize: fontSize,
          fontColor: fontColor,
        ),
      );
    }

    return result;
  }

  List<Color?> _parseFills(XmlDocument document) {
    final fillsElement = document.findAllElements('fills').firstOrNull;
    if (fillsElement == null) {
      return const [];
    }

    final result = <Color?>[];

    for (final fill in fillsElement.findElements('fill')) {
      final fgColor = fill.findAllElements('fgColor').isEmpty
          ? null
          : fill.findAllElements('fgColor').first;

      result.add(_parseColor(fgColor));
    }

    return result;
  }

  Color? _parseColor(XmlElement? element) {
    if (element == null) {
      return null;
    }

    final rgb = element.getAttribute('rgb');
    if (rgb == null || rgb.length != 8) {
      return null;
    }

    final value = int.tryParse(rgb, radix: 16);
    if (value == null) {
      return null;
    }

    return Color(value);
  }
}
