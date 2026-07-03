import 'package:flutter/material.dart';

/// Basic visual style for a spreadsheet cell.
class ExcelCellStyle {
  final bool bold;
  final bool italic;
  final double? fontSize;
  final Color? fontColor;
  final Color? backgroundColor;

  const ExcelCellStyle({
    this.bold = false,
    this.italic = false,
    this.fontSize,
    this.fontColor,
    this.backgroundColor,
  });

  static const empty = ExcelCellStyle();
}
