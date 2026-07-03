import 'package:flutter/material.dart';

/// Border sides for a spreadsheet cell.
class ExcelCellBorders {
  final BorderSide? top;
  final BorderSide? right;
  final BorderSide? bottom;
  final BorderSide? left;

  const ExcelCellBorders({
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  static const empty = ExcelCellBorders();

  bool get isEmpty =>
      top == null && right == null && bottom == null && left == null;

  Border? toBorder() {
    if (isEmpty) {
      return null;
    }

    return Border(
      top: top ?? BorderSide.none,
      right: right ?? BorderSide.none,
      bottom: bottom ?? BorderSide.none,
      left: left ?? BorderSide.none,
    );
  }
}
