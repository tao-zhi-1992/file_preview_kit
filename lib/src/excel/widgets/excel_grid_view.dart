import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../core/file_preview_kit_texts.dart';
import '../models/excel_sheet.dart';

const _minimumColumnWidth = 48.0;
const _minimumRowHeight = 24.0;
const _resizeHandleExtent = 16.0;

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
  State<ExcelGridView> createState() => _ExcelGridViewState();
}

class _ExcelGridViewState extends State<ExcelGridView>
    with AutomaticKeepAliveClientMixin {
  final _columnWidths = <int, double>{};
  final _rowHeights = <int, double>{};

  _GridSelection? _selection;
  _ResizeAxis? _resizeAxis;
  int? _resizeIndex;
  Offset? _dragStartGlobalPosition;
  double? _dragStartExtent;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant ExcelGridView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.sheet, widget.sheet)) {
      _columnWidths.clear();
      _rowHeights.clear();
      _selection = null;
      _clearResizeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.sheet.rows.isEmpty) {
      return Center(child: Text(widget.texts.emptySheet));
    }

    return _buildTable(context);
  }

  Widget _buildTable(BuildContext context) {
    return TableView.builder(
      pinnedRowCount: 1,
      pinnedColumnCount: 1,
      rowCount: widget.sheet.rowCount + 1,
      columnCount: widget.sheet.columnCount + 1,
      columnBuilder: (column) {
        final width = column == 0
            ? widget.rowHeaderWidth
            : _columnWidths[column - 1] ?? widget.cellWidth;

        return TableSpan(
          extent: FixedTableSpanExtent(width),
          foregroundDecoration: _spanBorder(context),
        );
      },
      rowBuilder: (row) {
        final height = row == 0
            ? widget.columnHeaderHeight
            : _rowHeights[row - 1] ?? widget.cellHeight;

        return TableSpan(
          extent: FixedTableSpanExtent(height),
          foregroundDecoration: _spanBorder(context),
          backgroundDecoration: TableSpanDecoration(
            color: row == 0
                ? Theme.of(context).colorScheme.surfaceContainerLow
                : Theme.of(context).colorScheme.surface,
          ),
        );
      },
      cellBuilder: (context, vicinity) {
        final row = vicinity.row;
        final column = vicinity.column;

        if (row == 0 && column == 0) {
          return TableViewCell(
            child: _HeaderCell(
              key: const ValueKey('excel-grid-corner'),
              text: '',
              selected: false,
              onTap: _clearSelection,
            ),
          );
        }

        if (row == 0) {
          final columnIndex = column - 1;
          final selected = _selection?.isColumn(columnIndex) ?? false;

          return TableViewCell(
            child: _HeaderCell(
              key: ValueKey('excel-column-header-$columnIndex'),
              text: _columnName(columnIndex),
              selected: selected,
              onTap: () => _selectColumn(columnIndex),
              resizeAxis: selected ? Axis.horizontal : null,
              resizeHandleKey: ValueKey(
                'excel-column-resize-handle-$columnIndex',
              ),
              resizeGripKey: const ValueKey('excel-column-resize-indicator'),
              onResizeStart: (details) => _startResize(
                axis: _ResizeAxis.column,
                index: columnIndex,
                details: details,
              ),
              onResizeUpdate: _updateResize,
              onResizeEnd: (_) => _finishResize(),
              onResizeCancel: _finishResize,
            ),
          );
        }

        if (column == 0) {
          final rowIndex = row - 1;
          final selected = _selection?.isRow(rowIndex) ?? false;

          return TableViewCell(
            child: _HeaderCell(
              key: ValueKey('excel-row-header-$rowIndex'),
              text: '$row',
              selected: selected,
              onTap: () => _selectRow(rowIndex),
              resizeAxis: selected ? Axis.vertical : null,
              resizeHandleKey: ValueKey('excel-row-resize-handle-$rowIndex'),
              resizeGripKey: const ValueKey('excel-row-resize-indicator'),
              onResizeStart: (details) => _startResize(
                axis: _ResizeAxis.row,
                index: rowIndex,
                details: details,
              ),
              onResizeUpdate: _updateResize,
              onResizeEnd: (_) => _finishResize(),
              onResizeCancel: _finishResize,
            ),
          );
        }

        final rowIndex = row - 1;
        final columnIndex = column - 1;
        final cell = widget.sheet.cellAt(rowIndex, columnIndex);
        final selected = _selection?.isCell(rowIndex, columnIndex) ?? false;
        final highlighted =
            selected ||
            (_selection?.isRow(rowIndex) ?? false) ||
            (_selection?.isColumn(columnIndex) ?? false);

        return TableViewCell(
          child: _BodyCell(
            key: ValueKey('excel-cell-$rowIndex-$columnIndex'),
            text: cell?.displayValue ?? '',
            selected: selected,
            highlighted: highlighted,
            onTap: () => _selectCell(rowIndex, columnIndex),
          ),
        );
      },
    );
  }

  void _selectCell(int rowIndex, int columnIndex) {
    setState(() {
      _selection = _GridSelection.cell(rowIndex, columnIndex);
      _clearResizeState();
    });
  }

  void _selectColumn(int columnIndex) {
    setState(() {
      _selection = _GridSelection.column(columnIndex);
      _clearResizeState();
    });
  }

  void _selectRow(int rowIndex) {
    setState(() {
      _selection = _GridSelection.row(rowIndex);
      _clearResizeState();
    });
  }

  void _clearSelection() {
    setState(() {
      _selection = null;
      _clearResizeState();
    });
  }

  void _startResize({
    required _ResizeAxis axis,
    required int index,
    required DragStartDetails details,
  }) {
    setState(() {
      _resizeAxis = axis;
      _resizeIndex = index;
      _dragStartGlobalPosition = details.globalPosition;
      _dragStartExtent = axis == _ResizeAxis.column
          ? _columnWidths[index] ?? widget.cellWidth
          : _rowHeights[index] ?? widget.cellHeight;
    });
  }

  void _updateResize(DragUpdateDetails details) {
    final axis = _resizeAxis;
    final index = _resizeIndex;
    final startPosition = _dragStartGlobalPosition;
    final startExtent = _dragStartExtent;

    if (axis == null ||
        index == null ||
        startPosition == null ||
        startExtent == null) {
      return;
    }

    final pointerDelta = axis == _ResizeAxis.column
        ? details.globalPosition.dx - startPosition.dx
        : details.globalPosition.dy - startPosition.dy;
    final minimumExtent = axis == _ResizeAxis.column
        ? _minimumColumnWidth
        : _minimumRowHeight;
    final extent = math.max(minimumExtent, startExtent + pointerDelta);

    setState(() {
      if (axis == _ResizeAxis.column) {
        _columnWidths[index] = extent;
      } else {
        _rowHeights[index] = extent;
      }
    });
  }

  void _finishResize() {
    setState(_clearResizeState);
  }

  void _clearResizeState() {
    _resizeAxis = null;
    _resizeIndex = null;
    _dragStartGlobalPosition = null;
    _dragStartExtent = null;
  }

  TableSpanDecoration _spanBorder(BuildContext context) {
    return TableSpanDecoration(
      border: TableSpanBorder(
        trailing: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
      ),
    );
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
}

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

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Axis? resizeAxis;
  final Key? resizeHandleKey;
  final Key? resizeGripKey;
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final GestureDragEndCallback? onResizeEnd;
  final GestureDragCancelCallback? onResizeCancel;

  const _HeaderCell({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
    this.resizeAxis,
    this.resizeHandleKey,
    this.resizeGripKey,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final textColor = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: backgroundColor,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
          if (resizeAxis != null) _buildResizeHandle(context),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grip = _HeaderResizeGrip(
      key: resizeGripKey,
      axis: resizeAxis == Axis.horizontal ? Axis.vertical : Axis.horizontal,
      color: colorScheme.primary,
      borderColor: colorScheme.surface,
      dotColor: colorScheme.onPrimary,
    );

    if (resizeAxis == Axis.horizontal) {
      return Positioned(
        key: resizeHandleKey,
        top: 0,
        right: 0,
        bottom: 0,
        width: _resizeHandleExtent,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: onResizeStart,
            onHorizontalDragUpdate: onResizeUpdate,
            onHorizontalDragEnd: onResizeEnd,
            onHorizontalDragCancel: onResizeCancel,
            child: Align(alignment: Alignment.centerRight, child: grip),
          ),
        ),
      );
    }

    return Positioned(
      key: resizeHandleKey,
      left: 0,
      right: 0,
      bottom: 0,
      height: _resizeHandleExtent,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: onResizeStart,
          onVerticalDragUpdate: onResizeUpdate,
          onVerticalDragEnd: onResizeEnd,
          onVerticalDragCancel: onResizeCancel,
          child: Align(alignment: Alignment.bottomCenter, child: grip),
        ),
      ),
    );
  }
}

class _HeaderResizeGrip extends StatelessWidget {
  final Axis axis;
  final Color color;
  final Color borderColor;
  final Color dotColor;

  const _HeaderResizeGrip({
    super.key,
    required this.axis,
    required this.color,
    required this.borderColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = axis == Axis.vertical;

    return Container(
      width: isVertical ? 8 : 20,
      height: isVertical ? 20 : 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: _ResizeGripDots(axis: axis, dotColor: dotColor),
    );
  }
}

class _ResizeGripDots extends StatelessWidget {
  final Axis axis;
  final Color dotColor;

  const _ResizeGripDots({required this.axis, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 2,
      height: 2,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );

    if (axis == Axis.vertical) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          dot,
          const SizedBox(height: 3),
          dot,
          const SizedBox(height: 3),
          dot,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot,
        const SizedBox(width: 3),
        dot,
        const SizedBox(width: 3),
        dot,
      ],
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _BodyCell({
    super.key,
    required this.text,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = highlighted
        ? theme.colorScheme.primary.withValues(alpha: selected ? 0.12 : 0.06)
        : theme.colorScheme.surface;

    return Semantics(
      selected: highlighted,
      button: true,
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: selected
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
