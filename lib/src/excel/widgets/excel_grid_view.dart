import 'package:flutter/material.dart';

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
    this.cellHeight = 44,
    this.rowHeaderWidth = 56,
    this.columnHeaderHeight = 36,
  });

  @override
  Widget build(BuildContext context) {
    if (sheet.rows.isEmpty) {
      return Center(child: Text(texts.emptySheet));
    }

    final totalWidth = rowHeaderWidth + sheet.columnCount * cellWidth;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              _buildColumnHeader(context),
              Expanded(
                child: ListView.builder(
                  itemCount: sheet.rowCount,
                  itemBuilder: (context, rowIndex) {
                    final row = sheet.rows[rowIndex];

                    return Row(
                      children: [
                        _HeaderCellBox(
                          width: rowHeaderWidth,
                          height: cellHeight,
                          text: '${rowIndex + 1}',
                        ),
                        for (final cell in row)
                          _ExcelCellBox(
                            width: cellWidth,
                            height: cellHeight,
                            text: cell.displayValue,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context) {
    return Row(
      children: [
        _HeaderCellBox(
          width: rowHeaderWidth,
          height: columnHeaderHeight,
          text: '',
        ),
        for (
          var columnIndex = 0;
          columnIndex < sheet.columnCount;
          columnIndex++
        )
          _HeaderCellBox(
            width: cellWidth,
            height: columnHeaderHeight,
            text: _columnName(columnIndex),
          ),
      ],
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

class _ExcelCellBox extends StatelessWidget {
  final double width;
  final double height;
  final String text;

  const _ExcelCellBox({
    required this.width,
    required this.height,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _HeaderCellBox extends StatelessWidget {
  final double width;
  final double height;
  final String text;

  const _HeaderCellBox({
    required this.width,
    required this.height,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    final backgroundColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
