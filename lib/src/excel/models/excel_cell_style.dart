import 'package:flutter/material.dart';

import 'excel_cell_alignment.dart';
import 'excel_cell_borders.dart';

/// Visual style for a spreadsheet cell.
class ExcelCellStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final double? fontSize;
  final String? fontFamily;
  final Color? fontColor;
  final Color? backgroundColor;
  final ExcelHorizontalAlign horizontalAlign;
  final ExcelVerticalAlign verticalAlign;
  final bool wrapText;
  final ExcelCellBorders borders;

  const ExcelCellStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize,
    this.fontFamily,
    this.fontColor,
    this.backgroundColor,
    this.horizontalAlign = ExcelHorizontalAlign.general,
    this.verticalAlign = ExcelVerticalAlign.bottom,
    this.wrapText = false,
    this.borders = ExcelCellBorders.empty,
  });

  static const empty = ExcelCellStyle();

  Alignment get alignment {
    final horizontal = switch (horizontalAlign) {
      ExcelHorizontalAlign.center => 0.0,
      ExcelHorizontalAlign.right => 1.0,
      ExcelHorizontalAlign.left || ExcelHorizontalAlign.general => -1.0,
    };
    final vertical = switch (verticalAlign) {
      ExcelVerticalAlign.center => 0.0,
      ExcelVerticalAlign.bottom => 1.0,
      ExcelVerticalAlign.top => -1.0,
    };
    return Alignment(horizontal, vertical);
  }
}
