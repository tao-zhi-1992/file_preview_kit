import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

/// Resolves Excel theme colors from `xl/theme/theme1.xml`.
class ExcelThemeColors {
  final List<Color> colors;

  const ExcelThemeColors(this.colors);

  Color? colorAt(int index) {
    if (index < 0 || index >= colors.length) {
      return null;
    }
    return colors[index];
  }

  static ExcelThemeColors? parse(String? xmlText) {
    if (xmlText == null || xmlText.isEmpty) {
      return null;
    }

    final document = XmlDocument.parse(xmlText);
    final scheme = document.findAllElements('clrScheme').firstOrNull;
    if (scheme == null) {
      return null;
    }

    final colors = <Color>[];
    for (final child in scheme.childElements) {
      final color = _parseThemeColorElement(child);
      if (color != null) {
        colors.add(color);
      }
    }

    return colors.isEmpty ? null : ExcelThemeColors(colors);
  }

  static Color? _parseThemeColorElement(XmlElement element) {
    final srgb = element.findElements('srgbClr').firstOrNull;
    if (srgb != null) {
      return _parseHexColor(srgb.getAttribute('val'));
    }

    final sys = element.findElements('sysClr').firstOrNull;
    if (sys != null) {
      return _parseHexColor(sys.getAttribute('lastClr'));
    }

    return null;
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null) {
      return null;
    }

    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    if (normalized.length != 8) {
      return null;
    }

    final value = int.tryParse(normalized, radix: 16);
    return value == null ? null : Color(value);
  }
}
