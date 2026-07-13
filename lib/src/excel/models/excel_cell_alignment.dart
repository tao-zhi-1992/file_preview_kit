/// Horizontal alignment for a spreadsheet cell.
enum ExcelHorizontalAlign {
  /// Default / general alignment.
  general,

  /// Left aligned.
  left,

  /// Center aligned.
  center,

  /// Centered across this cell and adjacent empty cells.
  centerContinuous,

  /// Right aligned.
  right,
}

/// Vertical alignment for a spreadsheet cell.
enum ExcelVerticalAlign {
  /// Top aligned.
  top,

  /// Center aligned.
  center,

  /// Bottom aligned.
  bottom,
}
