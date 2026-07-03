import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/file_preview_kit_theme.dart';
import '../models/docx_document.dart';

class DocxPreviewView extends StatelessWidget {
  final DocxDocument document;
  final ThemeData? theme;

  const DocxPreviewView({super.key, required this.document, this.theme});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme ?? FilePreviewKitTheme.light,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: document.blocks.length,
        itemBuilder: (context, index) =>
            _DocxBlockView(block: document.blocks[index]),
      ),
    );
  }
}

class _DocxBlockView extends StatelessWidget {
  final DocxBlock block;

  const _DocxBlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      DocxParagraph paragraph => _DocxParagraphView(paragraph: paragraph),
      DocxTable table => _DocxTableView(table: table),
      DocxImage image => _DocxImageView(image: image),
    };
  }
}

class _DocxParagraphView extends StatelessWidget {
  final DocxParagraph paragraph;

  const _DocxParagraphView({required this.paragraph});

  @override
  Widget build(BuildContext context) {
    final baseStyle = _textStyle(context);
    final list = paragraph.list;
    final style = paragraph.style;
    final defaultSpacingBefore = switch (style.kind) {
      DocxBuiltinKind.title ||
      DocxBuiltinKind.subtitle ||
      DocxBuiltinKind.heading1 ||
      DocxBuiltinKind.heading2 ||
      DocxBuiltinKind.heading3 =>
        16.0,
      _ => 0.0,
    };
    final defaultSpacingAfter = list == null ? 8.0 : 4.0;

    return Padding(
      padding: EdgeInsets.only(
        left: (list?.level ?? 0) * 24,
        top: style.spacingBefore ?? defaultSpacingBefore,
        bottom: style.spacingAfter ?? defaultSpacingAfter,
      ),
      child: RichText(
        textAlign: switch (style.align) {
          DocxParagraphAlignment.left => TextAlign.left,
          DocxParagraphAlignment.center => TextAlign.center,
          DocxParagraphAlignment.right => TextAlign.right,
          DocxParagraphAlignment.justify => TextAlign.justify,
          null => TextAlign.start,
        },
        text: TextSpan(
          style: baseStyle,
          children: [
            if (list != null)
              TextSpan(
                text: list.type == DocxListType.bullet
                    ? '${_bullet(list.level)} '
                    : '${list.number ?? 1}. ',
              ),
            for (final run in paragraph.runs)
              TextSpan(
                text: run.text,
                style: TextStyle(
                  fontWeight: run.style.bold ? FontWeight.bold : null,
                  fontStyle: run.style.italic ? FontStyle.italic : null,
                  decoration: _decoration(run.style),
                  fontSize: run.style.fontSize,
                  color:
                      run.style.color == null ? null : Color(run.style.color!),
                  backgroundColor: run.style.highlightColor == null
                      ? null
                      : Color(run.style.highlightColor!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _textStyle(BuildContext context) {
    final normal = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: 16, height: paragraph.style.lineHeight ?? 1.5);

    return switch (paragraph.style.kind) {
      DocxBuiltinKind.title =>
        normal.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
      DocxBuiltinKind.subtitle =>
        normal.copyWith(fontSize: 18, fontStyle: FontStyle.italic),
      DocxBuiltinKind.heading1 =>
        normal.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
      DocxBuiltinKind.heading2 =>
        normal.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      DocxBuiltinKind.heading3 =>
        normal.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      _ => normal,
    };
  }

  String _bullet(int level) => const ['•', '◦', '▪'][level % 3];

  TextDecoration? _decoration(DocxTextStyle textStyle) {
    final decorations = [
      if (textStyle.underline) TextDecoration.underline,
      if (textStyle.strike) TextDecoration.lineThrough,
    ];
    return decorations.isEmpty ? null : TextDecoration.combine(decorations);
  }
}

class _DocxImageView extends StatelessWidget {
  final DocxImage image;

  const _DocxImageView({required this.image});

  @override
  Widget build(BuildContext context) {
    if (image.bytes.isEmpty ||
        !_supportedContentTypes.contains(image.contentType)) {
      return _brokenImage(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final requestedWidth = image.width;
          final width = requestedWidth == null || !constraints.hasBoundedWidth
              ? requestedWidth
              : math.min(requestedWidth, constraints.maxWidth);
          final height =
              width == null ||
                  requestedWidth == null ||
                  requestedWidth == 0 ||
                  image.height == null
              ? image.height
              : image.height! * width / requestedWidth;

          return Align(
            alignment: Alignment.centerLeft,
            child: Image.memory(
              image.bytes,
              key: const ValueKey('docx-image'),
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _brokenImage(context),
            ),
          );
        },
      ),
    );
  }

  Widget _brokenImage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Icon(
        Icons.broken_image_outlined,
        key: const ValueKey('docx-image-unavailable'),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        semanticLabel: 'Image unavailable',
      ),
    );
  }
}

const _supportedContentTypes = {'image/png', 'image/jpeg'};

class _DocxTableView extends StatelessWidget {
  final DocxTable table;

  const _DocxTableView({required this.table});

  @override
  Widget build(BuildContext context) {
    final columnCount = table.rows.fold<int>(0, (count, row) {
      final columns = row.cells.fold<int>(
        0,
        (total, cell) => total + cell.columnSpan,
      );
      return columns > count ? columns : count;
    });

    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
            _buildRow(context, table.rows[rowIndex], rowIndex, columnCount),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    DocxTableRow row,
    int rowIndex,
    int columnCount,
  ) {
    var columnIndex = 0;
    final children = <Widget>[];

    for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
      final cell = row.cells[cellIndex];
      children.add(
        Expanded(
          flex: _cellFlex(cell, columnIndex),
          child: _buildCell(context, cell, rowIndex, cellIndex),
        ),
      );
      columnIndex += cell.columnSpan;
    }

    if (columnIndex < columnCount) {
      children.add(
        Expanded(
          flex: _columnFlex(columnIndex, columnCount - columnIndex),
          child: _buildCell(
            context,
            const DocxTableCell(blocks: []),
            rowIndex,
            row.cells.length,
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    DocxTableCell cell,
    int rowIndex,
    int cellIndex,
  ) {
    return Container(
      key: ValueKey('docx-table-cell-$rowIndex-$cellIndex'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: table.hasBorders ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in cell.blocks) _DocxBlockView(block: block),
        ],
      ),
    );
  }

  int _cellFlex(DocxTableCell cell, int columnIndex) {
    final width = cell.width;
    return width == null
        ? _columnFlex(columnIndex, cell.columnSpan)
        : math.max(1, width.round());
  }

  int _columnFlex(int start, int span) {
    var width = 0.0;

    for (var index = start; index < start + span; index++) {
      width += index < table.columnWidths.length
          ? table.columnWidths[index] ?? 100
          : 100;
    }

    return math.max(1, width.round());
  }
}
