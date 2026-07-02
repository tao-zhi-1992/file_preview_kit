import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../core/file_preview_kit_texts.dart';
import '../models/excel_sheet.dart';

class ExcelGridView extends StatelessWidget {
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
    this.cellHeight = 40,
    this.rowHeaderWidth = 56,
    this.columnHeaderHeight = 36,
  });

  @override
  Widget build(BuildContext context) {
    if (sheet.rows.isEmpty) {
      return Center(child: Text(texts.emptySheet));
    }

    return TableView.builder(
      pinnedRowCount: 1,
      pinnedColumnCount: 1,
      rowCount: sheet.rowCount + 1,
      columnCount: sheet.columnCount + 1,
      columnBuilder: (column) {
        return TableSpan(
          extent: FixedTableSpanExtent(
            column == 0 ? rowHeaderWidth : cellWidth,
          ),
          foregroundDecoration: _spanBorder(context),
        );
      },
      rowBuilder: (row) {
        return TableSpan(
          extent: FixedTableSpanExtent(
            row == 0 ? columnHeaderHeight : cellHeight,
          ),
          foregroundDecoration: _spanBorder(context),
          backgroundDecoration: TableSpanDecoration(
            color: row == 0
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surface,
          ),
        );
      },
      cellBuilder: (context, vicinity) {
        final row = vicinity.row;
        final column = vicinity.column;

        if (row == 0 && column == 0) {
          return const TableViewCell(child: SizedBox.expand());
        }

        if (row == 0) {
          return TableViewCell(
            child: _HeaderCell(text: _columnName(column - 1)),
          );
        }

        if (column == 0) {
          return TableViewCell(child: _HeaderCell(text: '$row'));
        }

        final cell = sheet.cellAt(row - 1, column - 1);

        return TableViewCell(child: _BodyCell(text: cell?.displayValue ?? ''));
      },
    );
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

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;

  const _BodyCell({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surface,
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
    );
  }
}
