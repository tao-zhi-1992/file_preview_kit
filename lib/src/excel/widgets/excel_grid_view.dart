import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/file_preview_kit_texts.dart';
import '../models/excel_cell_borders.dart';
import '../models/excel_cell_style.dart';
import '../models/excel_merge_region.dart';
import '../models/excel_sheet.dart';
import '../parser/excel_border_resolver.dart';

const _minimumColumnWidth = 48.0;
const _minimumRowHeight = 24.0;
const _resizeHandleExtent = 16.0;
const _extraGridLineCount = 10;
const _cellPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
const _maxCachedTextLayouts = 512;

/// Canvas-based spreadsheet grid.
///
/// The whole visible region (headers and body cells) is painted by a single
/// [CustomPainter]; scrolling only shifts paint offsets instead of building
/// and destroying per-cell widgets, which keeps fast diagonal pans smooth.
class ExcelGridView extends StatefulWidget {
  final ExcelSheet sheet;
  final FilePreviewKitTexts texts;
  final double cellWidth;
  final double cellHeight;
  final double rowHeaderWidth;
  final double columnHeaderHeight;

  const ExcelGridView({
    super.key,
    required this.sheet,
    required this.texts,
    this.cellWidth = 120,
    this.cellHeight = 36,
    this.rowHeaderWidth = 56,
    this.columnHeaderHeight = 36,
  });

  @override
  State<ExcelGridView> createState() => ExcelGridViewState();
}

/// State is public so widget tests can probe selection, sizes, and scrolling
/// through the [visibleForTesting] members; treat everything else as private.
class ExcelGridViewState extends State<ExcelGridView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ValueNotifier<Offset> _scroll = ValueNotifier<Offset>(Offset.zero);
  final Map<int, double> _columnWidths = <int, double>{};
  final Map<int, double> _rowHeights = <int, double>{};
  final _PaintStats _paintStats = _PaintStats();
  final _TextLayoutCache _textLayouts = _TextLayoutCache();

  _GridSelection? _selection;
  late _GridMetrics _metrics;
  Size _viewportSize = Size.zero;

  Ticker? _flingTicker;
  ClampingScrollSimulation? _flingX;
  ClampingScrollSimulation? _flingY;

  _ResizeDrag? _resizeDrag;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _seedColumnWidths();
    _metrics = _buildMetrics();
  }

  @override
  void didUpdateWidget(covariant ExcelGridView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sheetChanged = !identical(oldWidget.sheet, widget.sheet);
    if (sheetChanged) {
      _columnWidths.clear();
      _rowHeights.clear();
      _seedColumnWidths();
      _selection = null;
      _resizeDrag = null;
      _scroll.value = Offset.zero;
    }
    if (sheetChanged ||
        oldWidget.cellWidth != widget.cellWidth ||
        oldWidget.cellHeight != widget.cellHeight ||
        oldWidget.rowHeaderWidth != widget.rowHeaderWidth ||
        oldWidget.columnHeaderHeight != widget.columnHeaderHeight) {
      _metrics = _buildMetrics();
    }
  }

  @override
  void dispose() {
    _flingTicker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _seedColumnWidths() {
    for (final entry in widget.sheet.columnWidths.entries) {
      _columnWidths.putIfAbsent(entry.key, () => entry.value);
    }
  }

  _GridMetrics _buildMetrics() {
    final columnCount = widget.sheet.columnCount + _extraGridLineCount;
    final rowCount = widget.sheet.rowCount + _extraGridLineCount;
    final columnOffsets = List<double>.filled(columnCount + 1, 0);
    for (var i = 0; i < columnCount; i++) {
      columnOffsets[i + 1] =
          columnOffsets[i] + (_columnWidths[i] ?? widget.cellWidth);
    }
    final rowOffsets = List<double>.filled(rowCount + 1, 0);
    for (var i = 0; i < rowCount; i++) {
      rowOffsets[i + 1] = rowOffsets[i] + (_rowHeights[i] ?? widget.cellHeight);
    }
    return _GridMetrics(
      headerWidth: widget.rowHeaderWidth,
      headerHeight: widget.columnHeaderHeight,
      columnOffsets: columnOffsets,
      rowOffsets: rowOffsets,
    );
  }

  // --- Scrolling ---

  Offset _clampScroll(Offset value) {
    final maxX = math.max(
      0.0,
      _metrics.headerWidth + _metrics.bodyWidth - _viewportSize.width,
    );
    final maxY = math.max(
      0.0,
      _metrics.headerHeight + _metrics.bodyHeight - _viewportSize.height,
    );
    return Offset(value.dx.clamp(0.0, maxX), value.dy.clamp(0.0, maxY));
  }

  void _scrollBy(Offset delta) {
    _scroll.value = _clampScroll(_scroll.value + delta);
  }

  void _stopFling() {
    _flingX = null;
    _flingY = null;
    _flingTicker?.stop();
  }

  void _startFling(Velocity velocity) {
    final pixelsPerSecond = velocity.pixelsPerSecond;
    _flingX = pixelsPerSecond.dx.abs() < 50
        ? null
        : ClampingScrollSimulation(
            position: _scroll.value.dx,
            velocity: -pixelsPerSecond.dx,
          );
    _flingY = pixelsPerSecond.dy.abs() < 50
        ? null
        : ClampingScrollSimulation(
            position: _scroll.value.dy,
            velocity: -pixelsPerSecond.dy,
          );
    if (_flingX == null && _flingY == null) {
      return;
    }
    _flingTicker ??= createTicker(_tickFling);
    _flingTicker
      ?..stop()
      ..start();
  }

  void _tickFling(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var x = _scroll.value.dx;
    var y = _scroll.value.dy;

    final simulationX = _flingX;
    if (simulationX != null) {
      x = simulationX.x(seconds);
      if (simulationX.isDone(seconds)) {
        _flingX = null;
      }
    }
    final simulationY = _flingY;
    if (simulationY != null) {
      y = simulationY.x(seconds);
      if (simulationY.isDone(seconds)) {
        _flingY = null;
      }
    }

    final clamped = _clampScroll(Offset(x, y));
    if (clamped.dx != x) {
      _flingX = null;
    }
    if (clamped.dy != y) {
      _flingY = null;
    }
    _scroll.value = clamped;

    if (_flingX == null && _flingY == null) {
      _flingTicker?.stop();
    }
  }

  // --- Gestures ---

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _stopFling();
      _scrollBy(event.scrollDelta);
    }
  }

  void _handleTapDown(TapDownDetails details) => _stopFling();

  void _handleTapUp(TapUpDetails details) {
    final target = _hitTarget(details.localPosition);
    switch (target.kind) {
      case _HitKind.corner:
        _clearSelection();
      case _HitKind.columnHeader:
        _selectColumn(target.columnIndex);
      case _HitKind.rowHeader:
        _selectRow(target.rowIndex);
      case _HitKind.cell:
        _selectCell(target.rowIndex, target.columnIndex);
    }
  }

  _HitTarget _hitTarget(Offset position) {
    final inHeaderRow = position.dy < _metrics.headerHeight;
    final inHeaderColumn = position.dx < _metrics.headerWidth;
    if (inHeaderRow && inHeaderColumn) {
      return const _HitTarget(_HitKind.corner, 0, 0);
    }

    final bodyX = position.dx - _metrics.headerWidth + _scroll.value.dx;
    final bodyY = position.dy - _metrics.headerHeight + _scroll.value.dy;
    if (inHeaderRow) {
      return _HitTarget(_HitKind.columnHeader, 0, _metrics.columnAt(bodyX));
    }
    if (inHeaderColumn) {
      return _HitTarget(_HitKind.rowHeader, _metrics.rowAt(bodyY), 0);
    }
    return _HitTarget(
      _HitKind.cell,
      _metrics.rowAt(bodyY),
      _metrics.columnAt(bodyX),
    );
  }

  void _handlePanDown(DragDownDetails details) {
    _stopFling();
    _resizeDrag = _resizeDragAt(details.localPosition);
  }

  _ResizeDrag? _resizeDragAt(Offset position) {
    final columnGrip = debugColumnGripRect;
    final selection = _selection;
    if (columnGrip != null &&
        selection != null &&
        columnGrip.contains(position)) {
      final index = selection.columnIndex;
      if (index != null) {
        return _ResizeDrag(
          axis: _ResizeAxis.column,
          index: index,
          startExtent: _metrics.columnWidth(index),
          startPosition: position,
        );
      }
    }
    final rowGrip = debugRowGripRect;
    if (rowGrip != null && selection != null && rowGrip.contains(position)) {
      final index = selection.rowIndex;
      if (index != null) {
        return _ResizeDrag(
          axis: _ResizeAxis.row,
          index: index,
          startExtent: _metrics.rowHeight(index),
          startPosition: position,
        );
      }
    }
    return null;
  }

  void _handlePanStart(DragStartDetails details) {
    final drag = _resizeDrag;
    if (drag != null) {
      _applyResize(drag, details.localPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final drag = _resizeDrag;
    if (drag == null) {
      _scrollBy(-details.delta);
      return;
    }
    _applyResize(drag, details.localPosition);
  }

  void _applyResize(_ResizeDrag drag, Offset localPosition) {
    final pointerDelta = drag.axis == _ResizeAxis.column
        ? localPosition.dx - drag.startPosition.dx
        : localPosition.dy - drag.startPosition.dy;
    final minimumExtent = drag.axis == _ResizeAxis.column
        ? _minimumColumnWidth
        : _minimumRowHeight;
    final extent = math.max(minimumExtent, drag.startExtent + pointerDelta);

    setState(() {
      if (drag.axis == _ResizeAxis.column) {
        _columnWidths[drag.index] = extent;
      } else {
        _rowHeights[drag.index] = extent;
      }
      _metrics = _buildMetrics();
      _scroll.value = _clampScroll(_scroll.value);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_resizeDrag != null) {
      _resizeDrag = null;
      return;
    }
    _startFling(details.velocity);
  }

  void _handlePanCancel() => _resizeDrag = null;

  // --- Selection ---

  void _selectCell(int rowIndex, int columnIndex) {
    final region = widget.sheet.mergeRegionAt(rowIndex, columnIndex);
    setState(
      () => _selection = _GridSelection.cell(
        region?.startRow ?? rowIndex,
        region?.startColumn ?? columnIndex,
      ),
    );
  }

  void _selectColumn(int columnIndex) {
    setState(() => _selection = _GridSelection.column(columnIndex));
  }

  void _selectRow(int rowIndex) {
    setState(() => _selection = _GridSelection.row(rowIndex));
  }

  void _clearSelection() {
    setState(() => _selection = null);
  }

  // --- Test hooks ---

  @visibleForTesting
  int get debugPaintedCellCount => _paintStats.paintedCells;

  @visibleForTesting
  Offset get debugScrollOffset => _scroll.value;

  @visibleForTesting
  void debugScrollTo(Offset offset) {
    _scroll.value = _clampScroll(offset);
  }

  @visibleForTesting
  bool isCellSelected(int rowIndex, int columnIndex) =>
      _selection?.isCell(rowIndex, columnIndex) ?? false;

  @visibleForTesting
  bool isRowSelected(int rowIndex) => _selection?.isRow(rowIndex) ?? false;

  @visibleForTesting
  bool isColumnSelected(int columnIndex) =>
      _selection?.isColumn(columnIndex) ?? false;

  @visibleForTesting
  bool isCellHighlighted(int rowIndex, int columnIndex) {
    final selection = _selection;
    if (selection == null) {
      return false;
    }
    return selection.isCell(rowIndex, columnIndex) ||
        selection.isRow(rowIndex) ||
        selection.isColumn(columnIndex);
  }

  @visibleForTesting
  double columnWidthAt(int columnIndex) => _metrics.columnWidth(columnIndex);

  @visibleForTesting
  double rowHeightAt(int rowIndex) => _metrics.rowHeight(rowIndex);

  @visibleForTesting
  Rect? get debugColumnGripRect => _columnGripRectFor(
    selection: _selection,
    metrics: _metrics,
    scroll: _scroll.value,
    viewportWidth: _viewportSize.width,
  );

  @visibleForTesting
  Rect? get debugRowGripRect => _rowGripRectFor(
    selection: _selection,
    metrics: _metrics,
    scroll: _scroll.value,
    viewportHeight: _viewportSize.height,
  );

  @visibleForTesting
  String debugDisplayValueAt(int rowIndex, int columnIndex) {
    final region = widget.sheet.mergeRegionAt(rowIndex, columnIndex);
    final cell = widget.sheet.cellAt(
      region?.startRow ?? rowIndex,
      region?.startColumn ?? columnIndex,
    );
    return cell?.displayValue ?? '';
  }

  @visibleForTesting
  Rect debugCellPaintRect(int rowIndex, int columnIndex) {
    final region = widget.sheet.mergeRegionAt(rowIndex, columnIndex);
    final startRow = region?.startRow ?? rowIndex;
    final startColumn = region?.startColumn ?? columnIndex;
    final endRow = region?.endRow ?? rowIndex;
    final endColumn = region?.endColumn ?? columnIndex;
    return Rect.fromLTRB(
      _metrics.columnOffsets[startColumn],
      _metrics.rowOffsets[startRow],
      _metrics.columnOffsets[endColumn + 1],
      _metrics.rowOffsets[endRow + 1],
    );
  }

  @visibleForTesting
  TextStyle debugTextStyleAt(int rowIndex, int columnIndex) {
    final region = widget.sheet.mergeRegionAt(rowIndex, columnIndex);
    final cell = widget.sheet.cellAt(
      region?.startRow ?? rowIndex,
      region?.startColumn ?? columnIndex,
    );
    final base = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    return _applyCellTextStyle(base, cell?.style ?? ExcelCellStyle.empty);
  }

  @visibleForTesting
  Color debugCellBackgroundAt(int rowIndex, int columnIndex) {
    final theme = Theme.of(context);
    final region = widget.sheet.mergeRegionAt(rowIndex, columnIndex);
    final cell = widget.sheet.cellAt(
      region?.startRow ?? rowIndex,
      region?.startColumn ?? columnIndex,
    );
    final base =
        (cell?.style ?? ExcelCellStyle.empty).backgroundColor ??
        theme.colorScheme.surface;
    if (!isCellHighlighted(rowIndex, columnIndex)) {
      return base;
    }
    final alpha = isCellSelected(rowIndex, columnIndex) ? 0.12 : 0.06;
    return Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: alpha),
      base,
    );
  }

  @visibleForTesting
  bool debugSheetContains(String displayValue) {
    for (final row in widget.sheet.rows) {
      for (final cell in row) {
        if (cell.displayValue == displayValue) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the body vertical divider after [afterColumn] is skipped for [rowIndex]
  /// because it falls inside a merge region.
  @visibleForTesting
  bool debugSkipsVerticalDivider({
    required int afterColumn,
    required int rowIndex,
  }) {
    return _isInternalVerticalMergeBoundary(
      sheet: widget.sheet,
      afterColumn: afterColumn,
      rowIndex: rowIndex,
    );
  }

  /// Whether the body horizontal divider after [afterRow] is skipped for
  /// [columnIndex] because it falls inside a merge region.
  @visibleForTesting
  bool debugSkipsHorizontalDivider({
    required int afterRow,
    required int columnIndex,
  }) {
    return _isInternalHorizontalMergeBoundary(
      sheet: widget.sheet,
      afterRow: afterRow,
      columnIndex: columnIndex,
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.sheet.rows.isEmpty) {
      return Center(child: Text(widget.texts.emptySheet));
    }

    final gridTheme = _GridTheme.of(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        final clamped = _clampScroll(_scroll.value);
        if (clamped != _scroll.value) {
          _scroll.value = clamped;
        }

        return Semantics(
          container: true,
          label: widget.sheet.name,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onPanDown: _handlePanDown,
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              onPanCancel: _handlePanCancel,
              child: CustomPaint(
                painter: _ExcelGridPainter(
                  sheet: widget.sheet,
                  metrics: _metrics,
                  scroll: _scroll,
                  selection: _selection,
                  theme: gridTheme,
                  textLayouts: _textLayouts,
                  stats: _paintStats,
                  textDirection: textDirection,
                ),
                willChange: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Shared layout helpers ---

Rect? _columnGripRectFor({
  required _GridSelection? selection,
  required _GridMetrics metrics,
  required Offset scroll,
  required double viewportWidth,
}) {
  final index = selection?.type == _SelectionType.column
      ? selection?.columnIndex
      : null;
  if (index == null) {
    return null;
  }
  final right =
      metrics.headerWidth + metrics.columnOffsets[index + 1] - scroll.dx;
  final left = right - _resizeHandleExtent;
  if (left < metrics.headerWidth || left > viewportWidth) {
    return null;
  }
  return Rect.fromLTWH(left, 0, _resizeHandleExtent, metrics.headerHeight);
}

Rect? _rowGripRectFor({
  required _GridSelection? selection,
  required _GridMetrics metrics,
  required Offset scroll,
  required double viewportHeight,
}) {
  final index = selection?.type == _SelectionType.row
      ? selection?.rowIndex
      : null;
  if (index == null) {
    return null;
  }
  final bottom =
      metrics.headerHeight + metrics.rowOffsets[index + 1] - scroll.dy;
  final top = bottom - _resizeHandleExtent;
  if (top < metrics.headerHeight || top > viewportHeight) {
    return null;
  }
  return Rect.fromLTWH(0, top, metrics.headerWidth, _resizeHandleExtent);
}

TextStyle _applyCellTextStyle(TextStyle base, ExcelCellStyle style) {
  return base.copyWith(
    fontWeight: style.bold ? FontWeight.w600 : FontWeight.normal,
    fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
    fontSize: style.fontSize,
    fontFamily: style.fontFamily,
    color: style.fontColor,
    decoration: _textDecoration(style),
  );
}

TextDecoration? _textDecoration(ExcelCellStyle style) {
  final decorations = <TextDecoration>[
    if (style.underline) TextDecoration.underline,
    if (style.strikethrough) TextDecoration.lineThrough,
  ];

  if (decorations.isEmpty) {
    return null;
  }

  return TextDecoration.combine(decorations);
}

String _columnName(int columnIndex) {
  var index = columnIndex + 1;
  final chars = <String>[];

  while (index > 0) {
    final remainder = (index - 1) % 26;
    chars.insert(0, String.fromCharCode('A'.codeUnitAt(0) + remainder));
    index = (index - 1) ~/ 26;
  }

  return chars.join();
}

bool _isInternalVerticalMergeBoundary({
  required ExcelSheet sheet,
  required int afterColumn,
  required int rowIndex,
}) {
  final left = sheet.mergeRegionAt(rowIndex, afterColumn);
  if (left == null) {
    return false;
  }
  final right = sheet.mergeRegionAt(rowIndex, afterColumn + 1);
  return identical(left, right);
}

bool _isInternalHorizontalMergeBoundary({
  required ExcelSheet sheet,
  required int afterRow,
  required int columnIndex,
}) {
  final top = sheet.mergeRegionAt(afterRow, columnIndex);
  if (top == null) {
    return false;
  }
  final bottom = sheet.mergeRegionAt(afterRow + 1, columnIndex);
  return identical(top, bottom);
}

// --- Support types ---

enum _SelectionType { cell, row, column }

class _GridSelection {
  final _SelectionType type;
  final int? rowIndex;
  final int? columnIndex;

  const _GridSelection._(this.type, this.rowIndex, this.columnIndex);

  const _GridSelection.cell(int rowIndex, int columnIndex)
    : this._(_SelectionType.cell, rowIndex, columnIndex);

  const _GridSelection.row(int rowIndex)
    : this._(_SelectionType.row, rowIndex, null);

  const _GridSelection.column(int columnIndex)
    : this._(_SelectionType.column, null, columnIndex);

  bool isCell(int rowIndex, int columnIndex) {
    return type == _SelectionType.cell &&
        this.rowIndex == rowIndex &&
        this.columnIndex == columnIndex;
  }

  bool isRow(int rowIndex) {
    return type == _SelectionType.row && this.rowIndex == rowIndex;
  }

  bool isColumn(int columnIndex) {
    return type == _SelectionType.column && this.columnIndex == columnIndex;
  }
}

enum _ResizeAxis { row, column }

class _ResizeDrag {
  final _ResizeAxis axis;
  final int index;
  final double startExtent;
  final Offset startPosition;

  const _ResizeDrag({
    required this.axis,
    required this.index,
    required this.startExtent,
    required this.startPosition,
  });
}

enum _HitKind { corner, columnHeader, rowHeader, cell }

class _HitTarget {
  final _HitKind kind;
  final int rowIndex;
  final int columnIndex;

  const _HitTarget(this.kind, this.rowIndex, this.columnIndex);
}

class _PaintStats {
  int paintedCells = 0;
}

class _GridMetrics {
  final double headerWidth;
  final double headerHeight;

  /// Cumulative x offsets of body columns; length is columnCount + 1.
  final List<double> columnOffsets;

  /// Cumulative y offsets of body rows; length is rowCount + 1.
  final List<double> rowOffsets;

  const _GridMetrics({
    required this.headerWidth,
    required this.headerHeight,
    required this.columnOffsets,
    required this.rowOffsets,
  });

  double get bodyWidth => columnOffsets.last;
  double get bodyHeight => rowOffsets.last;
  int get columnCount => columnOffsets.length - 1;
  int get rowCount => rowOffsets.length - 1;

  double columnWidth(int index) =>
      columnOffsets[index + 1] - columnOffsets[index];

  double rowHeight(int index) => rowOffsets[index + 1] - rowOffsets[index];

  int columnAt(double position) => _spanIndexAt(columnOffsets, position);

  int rowAt(double position) => _spanIndexAt(rowOffsets, position);

  static int _spanIndexAt(List<double> offsets, double position) {
    if (position <= 0) {
      return 0;
    }
    var low = 0;
    var high = offsets.length - 2;
    if (position >= offsets[high]) {
      return high;
    }
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (offsets[mid] <= position) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}

class _GridTheme {
  final Color surface;
  final Color headerBackground;
  final Color headerSelectedBackground;
  final Color headerForeground;
  final Color headerSelectedForeground;
  final Color divider;
  final Color primary;
  final Color onPrimary;
  final TextStyle bodyStyle;
  final TextStyle headerStyle;

  const _GridTheme({
    required this.surface,
    required this.headerBackground,
    required this.headerSelectedBackground,
    required this.headerForeground,
    required this.headerSelectedForeground,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.bodyStyle,
    required this.headerStyle,
  });

  factory _GridTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _GridTheme(
      surface: colors.surface,
      headerBackground: colors.surfaceContainerLow,
      headerSelectedBackground: colors.primaryContainer,
      headerForeground: colors.onSurfaceVariant,
      headerSelectedForeground: colors.onPrimaryContainer,
      divider: theme.dividerColor,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      bodyStyle: theme.textTheme.bodySmall ?? const TextStyle(),
      headerStyle: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TextLayoutCache {
  final Map<String, TextPainter> _layouts = <String, TextPainter>{};

  TextPainter obtain({
    required String text,
    required TextStyle style,
    required bool wrap,
    required double maxWidth,
    required TextDirection direction,
  }) {
    final width = math.max(0, maxWidth.ceil()).toDouble();
    final key = '${style.hashCode}|$wrap|$width|${direction.index}|$text';
    final cached = _layouts.remove(key);
    if (cached != null) {
      _layouts[key] = cached;
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: wrap ? null : 1,
      ellipsis: wrap ? null : '…',
    )..layout(maxWidth: width);
    _layouts[key] = painter;
    if (_layouts.length > _maxCachedTextLayouts) {
      _layouts.remove(_layouts.keys.first);
    }
    return painter;
  }
}

// --- Painter ---

class _ExcelGridPainter extends CustomPainter {
  final ExcelSheet sheet;
  final _GridMetrics metrics;
  final ValueListenable<Offset> scroll;
  final _GridSelection? selection;
  final _GridTheme theme;
  final _TextLayoutCache textLayouts;
  final _PaintStats stats;
  final TextDirection textDirection;

  _ExcelGridPainter({
    required this.sheet,
    required this.metrics,
    required this.scroll,
    required this.selection,
    required this.theme,
    required this.textLayouts,
    required this.stats,
    required this.textDirection,
  }) : super(repaint: scroll);

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scroll.value;
    final bodyRect = Rect.fromLTWH(
      metrics.headerWidth,
      metrics.headerHeight,
      math.max(0, size.width - metrics.headerWidth),
      math.max(0, size.height - metrics.headerHeight),
    );

    canvas.drawRect(Offset.zero & size, Paint()..color = theme.surface);
    _paintBody(canvas, bodyRect, offset);
    _paintColumnHeaders(canvas, size, offset);
    _paintRowHeaders(canvas, size, offset);
    _paintCorner(canvas);
    _paintDividers(canvas, size, offset);
    _paintSelectedCellBorder(canvas, bodyRect, offset);
    _paintGrips(canvas, size, offset);
  }

  void _paintBody(Canvas canvas, Rect bodyRect, Offset offset) {
    if (bodyRect.isEmpty) {
      stats.paintedCells = 0;
      return;
    }

    canvas.save();
    canvas.clipRect(bodyRect);

    final firstColumn = metrics.columnAt(offset.dx);
    final lastColumn = metrics.columnAt(offset.dx + bodyRect.width);
    final firstRow = metrics.rowAt(offset.dy);
    final lastRow = metrics.rowAt(offset.dy + bodyRect.height);

    final paintedOrigins = <int>{};
    var painted = 0;
    for (var row = firstRow; row <= lastRow; row++) {
      for (var column = firstColumn; column <= lastColumn; column++) {
        final region = sheet.mergeRegionAt(row, column);
        final originRow = region?.startRow ?? row;
        final originColumn = region?.startColumn ?? column;
        if (region != null) {
          final originKey = originRow * metrics.columnCount + originColumn;
          if (!paintedOrigins.add(originKey)) {
            continue;
          }
        }
        painted++;

        final rect = _cellRect(region, originRow, originColumn, offset);
        final cell = sheet.cellAt(originRow, originColumn);
        final style = cell?.style ?? ExcelCellStyle.empty;

        final background = style.backgroundColor;
        if (background != null) {
          canvas.drawRect(rect, Paint()..color = background);
        }
        if (originRow < sheet.rowCount && originColumn < sheet.columnCount) {
          final borders = sheet.resolvedBordersAt(
            originRow: originRow,
            originColumn: originColumn,
            compute: () => ExcelBorderResolver.resolve(
              sheet,
              rowIndex: originRow,
              columnIndex: originColumn,
              mergeRegion: region,
            ),
          );
          _paintCellBorders(canvas, rect, borders);
        }

        final text = cell?.displayValue ?? '';
        if (text.isNotEmpty) {
          _paintCellText(canvas, rect, text, style);
        }
      }
    }
    stats.paintedCells = painted;

    _paintSelectionFill(canvas, bodyRect, offset);
    canvas.restore();
  }

  Rect _cellRect(
    ExcelMergeRegion? region,
    int originRow,
    int originColumn,
    Offset offset,
  ) {
    final endRow = region?.endRow ?? originRow;
    final endColumn = region?.endColumn ?? originColumn;
    return Rect.fromLTRB(
      metrics.headerWidth + metrics.columnOffsets[originColumn] - offset.dx,
      metrics.headerHeight + metrics.rowOffsets[originRow] - offset.dy,
      metrics.headerWidth + metrics.columnOffsets[endColumn + 1] - offset.dx,
      metrics.headerHeight + metrics.rowOffsets[endRow + 1] - offset.dy,
    );
  }

  void _paintCellBorders(Canvas canvas, Rect rect, ExcelCellBorders borders) {
    final left = borders.left;
    if (left != null) {
      final x = rect.left + left.width / 2;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        left.toPaint(),
      );
    }
    final top = borders.top;
    if (top != null) {
      final y = rect.top + top.width / 2;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        top.toPaint(),
      );
    }
    final right = borders.right;
    if (right != null) {
      final x = rect.right - right.width / 2;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        right.toPaint(),
      );
    }
    final bottom = borders.bottom;
    if (bottom != null) {
      final y = rect.bottom - bottom.width / 2;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        bottom.toPaint(),
      );
    }
  }

  void _paintCellText(
    Canvas canvas,
    Rect rect,
    String text,
    ExcelCellStyle style,
  ) {
    final padded = _cellPadding.resolve(textDirection).deflateRect(rect);
    if (padded.width <= 0 || padded.height <= 0) {
      return;
    }
    final painter = textLayouts.obtain(
      text: text,
      style: _applyCellTextStyle(theme.bodyStyle, style),
      wrap: style.wrapText,
      maxWidth: padded.width,
      direction: textDirection,
    );
    final aligned = style.alignment.inscribe(painter.size, padded);
    painter.paint(canvas, aligned.topLeft);
  }

  void _paintSelectionFill(Canvas canvas, Rect bodyRect, Offset offset) {
    final currentSelection = selection;
    if (currentSelection == null) {
      return;
    }

    switch (currentSelection.type) {
      case _SelectionType.column:
        final index = currentSelection.columnIndex;
        if (index == null) {
          return;
        }
        final left =
            metrics.headerWidth + metrics.columnOffsets[index] - offset.dx;
        final rect = Rect.fromLTWH(
          left,
          bodyRect.top,
          metrics.columnWidth(index),
          bodyRect.height,
        );
        canvas.drawRect(
          rect,
          Paint()..color = theme.primary.withValues(alpha: 0.06),
        );
      case _SelectionType.row:
        final index = currentSelection.rowIndex;
        if (index == null) {
          return;
        }
        final top =
            metrics.headerHeight + metrics.rowOffsets[index] - offset.dy;
        final rect = Rect.fromLTWH(
          bodyRect.left,
          top,
          bodyRect.width,
          metrics.rowHeight(index),
        );
        canvas.drawRect(
          rect,
          Paint()..color = theme.primary.withValues(alpha: 0.06),
        );
      case _SelectionType.cell:
        final rowIndex = currentSelection.rowIndex;
        final columnIndex = currentSelection.columnIndex;
        if (rowIndex == null || columnIndex == null) {
          return;
        }
        final region = sheet.mergeRegionAt(rowIndex, columnIndex);
        final rect = _cellRect(
          region,
          region?.startRow ?? rowIndex,
          region?.startColumn ?? columnIndex,
          offset,
        );
        canvas.drawRect(
          rect,
          Paint()..color = theme.primary.withValues(alpha: 0.12),
        );
    }
  }

  void _paintColumnHeaders(Canvas canvas, Size size, Offset offset) {
    final strip = Rect.fromLTWH(
      metrics.headerWidth,
      0,
      math.max(0, size.width - metrics.headerWidth),
      metrics.headerHeight,
    );
    if (strip.isEmpty) {
      return;
    }

    canvas.save();
    canvas.clipRect(strip);
    canvas.drawRect(strip, Paint()..color = theme.headerBackground);

    final firstColumn = metrics.columnAt(offset.dx);
    final lastColumn = metrics.columnAt(offset.dx + strip.width);
    for (var column = firstColumn; column <= lastColumn; column++) {
      final left =
          metrics.headerWidth + metrics.columnOffsets[column] - offset.dx;
      final rect = Rect.fromLTWH(
        left,
        0,
        metrics.columnWidth(column),
        metrics.headerHeight,
      );
      final selected = selection?.isColumn(column) ?? false;
      if (selected) {
        canvas.drawRect(rect, Paint()..color = theme.headerSelectedBackground);
      }
      _paintHeaderLabel(canvas, rect, _columnName(column), selected);
    }
    canvas.restore();
  }

  void _paintRowHeaders(Canvas canvas, Size size, Offset offset) {
    final strip = Rect.fromLTWH(
      0,
      metrics.headerHeight,
      metrics.headerWidth,
      math.max(0, size.height - metrics.headerHeight),
    );
    if (strip.isEmpty) {
      return;
    }

    canvas.save();
    canvas.clipRect(strip);
    canvas.drawRect(strip, Paint()..color = theme.headerBackground);

    final firstRow = metrics.rowAt(offset.dy);
    final lastRow = metrics.rowAt(offset.dy + strip.height);
    for (var row = firstRow; row <= lastRow; row++) {
      final top = metrics.headerHeight + metrics.rowOffsets[row] - offset.dy;
      final rect = Rect.fromLTWH(
        0,
        top,
        metrics.headerWidth,
        metrics.rowHeight(row),
      );
      final selected = selection?.isRow(row) ?? false;
      if (selected) {
        canvas.drawRect(rect, Paint()..color = theme.headerSelectedBackground);
      }
      _paintHeaderLabel(canvas, rect, '${row + 1}', selected);
    }
    canvas.restore();
  }

  void _paintHeaderLabel(Canvas canvas, Rect rect, String text, bool selected) {
    final painter = textLayouts.obtain(
      text: text,
      style: theme.headerStyle.copyWith(
        color: selected
            ? theme.headerSelectedForeground
            : theme.headerForeground,
      ),
      wrap: false,
      maxWidth: rect.width,
      direction: textDirection,
    );
    final aligned = Alignment.center.inscribe(painter.size, rect);
    painter.paint(canvas, aligned.topLeft);
  }

  void _paintCorner(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, metrics.headerWidth, metrics.headerHeight),
      Paint()..color = theme.headerBackground,
    );
  }

  void _paintDividers(Canvas canvas, Size size, Offset offset) {
    final paint = Paint()
      ..color = theme.divider
      ..strokeWidth = 0.5;

    canvas.drawLine(
      Offset(metrics.headerWidth, 0),
      Offset(metrics.headerWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, metrics.headerHeight),
      Offset(size.width, metrics.headerHeight),
      paint,
    );

    final firstColumn = metrics.columnAt(offset.dx);
    final lastColumn = metrics.columnAt(
      offset.dx + math.max(0, size.width - metrics.headerWidth),
    );
    final firstRow = metrics.rowAt(offset.dy);
    final lastRow = metrics.rowAt(
      offset.dy + math.max(0, size.height - metrics.headerHeight),
    );

    for (var column = firstColumn; column <= lastColumn; column++) {
      final x =
          metrics.headerWidth + metrics.columnOffsets[column + 1] - offset.dx;
      if (x <= metrics.headerWidth || x > size.width) {
        continue;
      }

      // Column headers are never merged; always draw the header strip.
      canvas.drawLine(Offset(x, 0), Offset(x, metrics.headerHeight), paint);

      // Body: skip segments that fall inside a horizontal merge.
      for (var row = firstRow; row <= lastRow; row++) {
        if (_isInternalVerticalMergeBoundary(
          sheet: sheet,
          afterColumn: column,
          rowIndex: row,
        )) {
          continue;
        }
        final top = metrics.headerHeight + metrics.rowOffsets[row] - offset.dy;
        final bottom =
            metrics.headerHeight + metrics.rowOffsets[row + 1] - offset.dy;
        final clippedTop = math.max(top, metrics.headerHeight);
        final clippedBottom = math.min(bottom, size.height);
        if (clippedBottom > clippedTop) {
          canvas.drawLine(
            Offset(x, clippedTop),
            Offset(x, clippedBottom),
            paint,
          );
        }
      }
    }

    for (var row = firstRow; row <= lastRow; row++) {
      final y = metrics.headerHeight + metrics.rowOffsets[row + 1] - offset.dy;
      if (y <= metrics.headerHeight || y > size.height) {
        continue;
      }

      // Row headers are never merged; always draw the header strip.
      canvas.drawLine(Offset(0, y), Offset(metrics.headerWidth, y), paint);

      // Body: skip segments that fall inside a vertical merge.
      for (var column = firstColumn; column <= lastColumn; column++) {
        if (_isInternalHorizontalMergeBoundary(
          sheet: sheet,
          afterRow: row,
          columnIndex: column,
        )) {
          continue;
        }
        final left =
            metrics.headerWidth + metrics.columnOffsets[column] - offset.dx;
        final right =
            metrics.headerWidth + metrics.columnOffsets[column + 1] - offset.dx;
        final clippedLeft = math.max(left, metrics.headerWidth);
        final clippedRight = math.min(right, size.width);
        if (clippedRight > clippedLeft) {
          canvas.drawLine(
            Offset(clippedLeft, y),
            Offset(clippedRight, y),
            paint,
          );
        }
      }
    }
  }

  void _paintSelectedCellBorder(Canvas canvas, Rect bodyRect, Offset offset) {
    final currentSelection = selection;
    if (currentSelection == null ||
        currentSelection.type != _SelectionType.cell) {
      return;
    }
    final rowIndex = currentSelection.rowIndex;
    final columnIndex = currentSelection.columnIndex;
    if (rowIndex == null || columnIndex == null) {
      return;
    }

    final region = sheet.mergeRegionAt(rowIndex, columnIndex);
    final rect = _cellRect(
      region,
      region?.startRow ?? rowIndex,
      region?.startColumn ?? columnIndex,
      offset,
    );
    if (!rect.overlaps(bodyRect)) {
      return;
    }

    canvas.save();
    canvas.clipRect(bodyRect);
    canvas.drawRect(
      rect.deflate(0.75),
      Paint()
        ..color = theme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _paintGrips(Canvas canvas, Size size, Offset offset) {
    final columnGrip = _columnGripRectFor(
      selection: selection,
      metrics: metrics,
      scroll: offset,
      viewportWidth: size.width,
    );
    if (columnGrip != null) {
      _paintGripIcon(
        canvas,
        Rect.fromCenter(
          center: Offset(columnGrip.right - 6, columnGrip.center.dy),
          width: 8,
          height: 20,
        ),
        vertical: true,
      );
    }

    final rowGrip = _rowGripRectFor(
      selection: selection,
      metrics: metrics,
      scroll: offset,
      viewportHeight: size.height,
    );
    if (rowGrip != null) {
      _paintGripIcon(
        canvas,
        Rect.fromCenter(
          center: Offset(rowGrip.center.dx, rowGrip.bottom - 6),
          width: 20,
          height: 8,
        ),
        vertical: false,
      );
    }
  }

  void _paintGripIcon(Canvas canvas, Rect icon, {required bool vertical}) {
    final rrect = RRect.fromRectAndRadius(icon, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = theme.primary);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final dotPaint = Paint()..color = theme.onPrimary;
    for (var i = -1; i <= 1; i++) {
      final center = vertical
          ? Offset(icon.center.dx, icon.center.dy + i * 5)
          : Offset(icon.center.dx + i * 5, icon.center.dy);
      canvas.drawCircle(center, 1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExcelGridPainter oldDelegate) => true;
}
