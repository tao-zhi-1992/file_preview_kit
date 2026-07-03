import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/file_preview_kit_theme.dart';
import '../models/docx_document.dart';

class DocxPreviewView extends StatelessWidget {
  final DocxDocument document;
  final ThemeData? theme;
  final ValueChanged<String>? onLinkTap;

  const DocxPreviewView({
    super.key,
    required this.document,
    this.theme,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme ?? FilePreviewKitTheme.light,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final block in document.blocks)
            _DocxBlockView(block: block, onLinkTap: onLinkTap),
          if (document.notes.isNotEmpty)
            _DocxReferencesView(
              title: 'Notes',
              entries: [
                for (var index = 0; index < document.notes.length; index++)
                  _DocxReferenceEntry(
                    label: '${index + 1}.',
                    blocks: document.notes[index].blocks,
                  ),
              ],
              onLinkTap: onLinkTap,
            ),
          if (document.comments.isNotEmpty)
            _DocxReferencesView(
              title: 'Comments',
              entries: [
                for (var index = 0; index < document.comments.length; index++)
                  _DocxReferenceEntry(
                    label:
                        '${document.comments[index].authorInitials ?? document.comments[index].authorName ?? ''} ${index + 1}.'
                            .trimLeft(),
                    blocks: document.comments[index].blocks,
                  ),
              ],
              onLinkTap: onLinkTap,
            ),
        ],
      ),
    );
  }
}

class _DocxBlockView extends StatelessWidget {
  final DocxBlock block;
  final ValueChanged<String>? onLinkTap;

  const _DocxBlockView({required this.block, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      DocxParagraph paragraph => _DocxParagraphView(
        paragraph: paragraph,
        onLinkTap: onLinkTap,
      ),
      DocxHyperlink hyperlink => _DocxHyperlinkView(hyperlink: hyperlink),
      DocxBreak break_ => _DocxBreakView(breakType: break_.breakType),
      DocxTable table => _DocxTableView(table: table, onLinkTap: onLinkTap),
      DocxImage image => _DocxImageView(image: image, onLinkTap: onLinkTap),
      DocxBookmarkStart _ => const SizedBox.shrink(),
    };
  }
}

// ---------------------------------------------------------------------------
// Paragraph
// ---------------------------------------------------------------------------

class _DocxParagraphView extends StatelessWidget {
  final DocxParagraph paragraph;
  final ValueChanged<String>? onLinkTap;

  const _DocxParagraphView({required this.paragraph, this.onLinkTap});

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
      DocxBuiltinKind.heading3 => 16.0,
      _ => 0.0,
    };
    final defaultSpacingAfter = list == null ? 8.0 : 4.0;

    return Padding(
      padding: EdgeInsets.only(
        left: (list?.level ?? 0) * 24 + (style.indentStart ?? 0),
        right: style.indentEnd ?? 0,
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
              _textSpanForRun(run, baseStyle, onLinkTap),
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
      DocxBuiltinKind.title => normal.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      DocxBuiltinKind.subtitle => normal.copyWith(
        fontSize: 18,
        fontStyle: FontStyle.italic,
      ),
      DocxBuiltinKind.heading1 => normal.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      DocxBuiltinKind.heading2 => normal.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      DocxBuiltinKind.heading3 => normal.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      _ => normal,
    };
  }

  String _bullet(int level) => const ['•', '◦', '▪'][level % 3];
}

// ---------------------------------------------------------------------------
// Hyperlink (standalone block)
// ---------------------------------------------------------------------------

class _DocxHyperlinkView extends StatelessWidget {
  final DocxHyperlink hyperlink;

  const _DocxHyperlinkView({required this.hyperlink});

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: 16,
      color: Colors.blue,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            for (final run in hyperlink.runs)
              _textSpanForRun(run, baseStyle, null),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Break (page / column)
// ---------------------------------------------------------------------------

class _DocxBreakView extends StatelessWidget {
  final DocxBreakType breakType;

  const _DocxBreakView({required this.breakType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: breakType == DocxBreakType.page ? 24 : 12,
      ),
      child: Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers (used by paragraph and hyperlink)
// ---------------------------------------------------------------------------

InlineSpan _textSpanForRun(
  DocxTextRun run,
  TextStyle baseStyle,
  ValueChanged<String>? onLinkTap,
) {
  final target = run.href ?? (run.anchor == null ? null : '#${run.anchor}');
  final runDecoration = _decoration(run.style);
  final style = TextStyle(
    fontWeight: run.style.bold
        ? FontWeight.bold
        : run.style.allCaps || run.style.smallCaps
        ? FontWeight.w500
        : null,
    fontStyle: run.style.italic ? FontStyle.italic : null,
    decoration: target == null
        ? runDecoration
        : TextDecoration.combine([
            runDecoration ?? TextDecoration.none,
            TextDecoration.underline,
          ]),
    fontSize: run.style.fontSize,
    fontFamily: run.style.fontFamily,
    color: run.style.color == null
        ? target == null
              ? null
              : Colors.blue
        : Color(run.style.color!),
    backgroundColor: run.style.highlightColor == null
        ? null
        : Color(run.style.highlightColor!),
    letterSpacing: run.style.allCaps || run.style.smallCaps ? 1.2 : null,
  );
  final text = _applyCaps(run.text, run.style);
  final verticalAlignment = run.style.verticalAlignment;
  if ((target != null && onLinkTap != null ||
          verticalAlignment == DocxVerticalAlignment.superscript ||
          verticalAlignment == DocxVerticalAlignment.subscript) &&
      text.isNotEmpty) {
    final effectiveStyle = baseStyle.merge(style);
    Widget child = Text(
      text,
      style:
          verticalAlignment == null ||
              verticalAlignment == DocxVerticalAlignment.baseline
          ? effectiveStyle
          : effectiveStyle.copyWith(
              fontSize: (effectiveStyle.fontSize ?? 16) * 0.75,
            ),
    );
    if (verticalAlignment == DocxVerticalAlignment.superscript ||
        verticalAlignment == DocxVerticalAlignment.subscript) {
      child = Transform.translate(
        offset: Offset(
          0,
          verticalAlignment == DocxVerticalAlignment.superscript ? -4 : 3,
        ),
        child: child,
      );
    }
    if (target != null && onLinkTap != null) {
      child = GestureDetector(onTap: () => onLinkTap(target), child: child);
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: child,
    );
  }
  return TextSpan(text: text, style: style);
}

TextDecoration? _decoration(DocxTextStyle textStyle) {
  final decorations = <TextDecoration>[
    if (textStyle.underline) TextDecoration.underline,
    if (textStyle.strike) TextDecoration.lineThrough,
  ];
  return decorations.isEmpty ? null : TextDecoration.combine(decorations);
}

String _applyCaps(String text, DocxTextStyle style) {
  if (style.allCaps) {
    return text.toUpperCase();
  }
  if (style.smallCaps) {
    return text.toUpperCase();
  }
  return text;
}

// ---------------------------------------------------------------------------
// Image
// ---------------------------------------------------------------------------

class _DocxImageView extends StatelessWidget {
  final DocxImage image;
  final ValueChanged<String>? onLinkTap;

  const _DocxImageView({required this.image, this.onLinkTap});

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

          final child = Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: image.altText,
              image: true,
              child: Image.memory(
                image.bytes,
                key: const ValueKey('docx-image'),
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _brokenImage(context),
              ),
            ),
          );
          return image.href == null || onLinkTap == null
              ? child
              : GestureDetector(
                  onTap: () => onLinkTap!(image.href!),
                  child: child,
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

const _supportedContentTypes = {'image/png', 'image/jpeg', 'image/gif'};

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

class _DocxTableView extends StatelessWidget {
  final DocxTable table;
  final ValueChanged<String>? onLinkTap;

  const _DocxTableView({required this.table, this.onLinkTap});

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
      if (cell.rowSpan > 0) {
        children.add(
          Expanded(
            flex: _cellFlex(cell, columnIndex),
            child: _buildCell(context, cell, rowIndex, cellIndex, row.isHeader),
          ),
        );
      }
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
            false,
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
    bool isHeader,
  ) {
    return Container(
      key: ValueKey('docx-table-cell-$rowIndex-$cellIndex'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: table.hasBorders ? 1 : 0.5,
        ),
        color: isHeader
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in cell.blocks)
            _DocxBlockView(block: block, onLinkTap: onLinkTap),
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

class _DocxReferenceEntry {
  final String label;
  final List<DocxBlock> blocks;

  const _DocxReferenceEntry({required this.label, required this.blocks});
}

class _DocxReferencesView extends StatelessWidget {
  final String title;
  final List<_DocxReferenceEntry> entries;
  final ValueChanged<String>? onLinkTap;

  const _DocxReferencesView({
    required this.title,
    required this.entries,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        for (final entry in entries)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Text(entry.label),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final block in entry.blocks)
                      _DocxBlockView(block: block, onLinkTap: onLinkTap),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
