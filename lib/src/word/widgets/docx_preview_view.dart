import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/file_preview_kit_theme.dart';
import '../../core/file_preview_kit_texts.dart';
import '../models/docx_document.dart';

/// Displays a parsed DOCX document as continuous scrollable content.
class DocxPreviewView extends StatelessWidget {
  /// Document to display.
  final DocxDocument document;

  /// Optional theme applied within the preview.
  final ThemeData? theme;

  /// Optional user-facing text overrides.
  final FilePreviewKitTexts? texts;

  /// Called when a hyperlink or bookmark is activated.
  final ValueChanged<String>? onLinkTap;

  /// Creates a DOCX preview.
  const DocxPreviewView({
    super.key,
    required this.document,
    this.theme,
    this.texts,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme ?? FilePreviewKitTheme.light,
      child: _DocxPreviewContent(
        document: document,
        texts: texts,
        onLinkTap: onLinkTap,
      ),
    );
  }
}

class _DocxPreviewContent extends StatelessWidget {
  const _DocxPreviewContent({
    required this.document,
    required this.texts,
    required this.onLinkTap,
  });

  final DocxDocument document;
  final FilePreviewKitTexts? texts;
  final ValueChanged<String>? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final resolvedTexts =
        texts ?? FilePreviewKitTexts.resolve(Localizations.localeOf(context));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final block in document.blocks)
          _DocxBlockView(
            block: block,
            texts: resolvedTexts,
            onLinkTap: onLinkTap,
          ),
        if (document.notes.isNotEmpty)
          _DocxReferencesView(
            title: 'Notes',
            texts: resolvedTexts,
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
            texts: resolvedTexts,
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
    );
  }
}

int _tableColumnCount(DocxTable table) {
  return table.rows.fold<int>(0, (count, row) {
    final columns = row.cells.fold<int>(
      0,
      (total, cell) => total + cell.columnSpan,
    );
    return math.max(count, columns);
  });
}

class _DocxBlockView extends StatelessWidget {
  final DocxBlock block;
  final FilePreviewKitTexts texts;
  final ValueChanged<String>? onLinkTap;

  const _DocxBlockView({
    required this.block,
    required this.texts,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      DocxParagraph paragraph => _DocxParagraphView(
        paragraph: paragraph,
        onLinkTap: onLinkTap,
      ),
      DocxHyperlink hyperlink => _DocxHyperlinkView(hyperlink: hyperlink),
      DocxBreak break_ => _DocxBreakView(breakType: break_.breakType),
      DocxTable table => _DocxTableView(
        table: table,
        texts: texts,
        onLinkTap: onLinkTap,
      ),
      DocxImage image => _DocxImageView(image: image, onLinkTap: onLinkTap),
      DocxUnsupportedContent unsupported => _DocxUnsupportedContentView(
        content: unsupported,
        message: texts.unsupportedDocxContentMessage,
      ),
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
    final baseStyle = _paragraphTextStyle(context, paragraph);
    final layout = _DocxParagraphLayout.resolve(paragraph, baseStyle);
    final content = _DocxParagraphRichText(
      paragraph: paragraph,
      baseStyle: baseStyle,
      firstLineIndent: layout.firstLineIndent,
      onLinkTap: onLinkTap,
    );

    return Padding(
      padding: layout.padding,
      child: layout.hasList
          ? _DocxListParagraphRow(
              marker: layout.listMarker,
              hangingIndent: layout.hangingIndent,
              markerStyle: layout.markerStyle,
              content: content,
            )
          : content,
    );
  }
}

class _DocxParagraphLayout {
  final EdgeInsets padding;
  final bool hasList;
  final String listMarker;
  final double hangingIndent;
  final TextStyle markerStyle;
  final double firstLineIndent;

  const _DocxParagraphLayout({
    required this.padding,
    required this.hasList,
    required this.listMarker,
    required this.hangingIndent,
    required this.markerStyle,
    required this.firstLineIndent,
  });

  factory _DocxParagraphLayout.resolve(
    DocxParagraph paragraph,
    TextStyle baseStyle,
  ) {
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
    final indentStart =
        style.indentStart ??
        list?.indentStart ??
        (list == null ? 0.0 : (list.level + 1) * 24.0);
    final hangingIndent =
        style.hangingIndent ??
        list?.hangingIndent ??
        (list == null ? 0.0 : 24.0);
    final listMarker = list == null
        ? ''
        : list.marker ??
              (list.type == DocxListType.bullet
                  ? const ['•', '◦', '▪'][list.level % 3]
                  : '${list.number ?? 1}.');
    final markerStyle = paragraph.runs.isEmpty
        ? baseStyle
        : baseStyle.merge(_runTextStyle(paragraph.runs.first, null));

    return _DocxParagraphLayout(
      padding: EdgeInsets.only(
        left: list == null
            ? math.max(0, indentStart)
            : math.max(0, indentStart - hangingIndent),
        right: math.max(0, style.indentEnd ?? 0),
        top: style.spacingBefore ?? defaultSpacingBefore,
        bottom: style.spacingAfter ?? defaultSpacingAfter,
      ),
      hasList: list != null,
      listMarker: listMarker,
      hangingIndent: hangingIndent,
      markerStyle: markerStyle,
      firstLineIndent: style.firstLineIndent ?? 0,
    );
  }
}

class _DocxListParagraphRow extends StatelessWidget {
  final String marker;
  final double hangingIndent;
  final TextStyle markerStyle;
  final Widget content;

  const _DocxListParagraphRow({
    required this.marker,
    required this.hangingIndent,
    required this.markerStyle,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocxListMarker(
          marker: marker,
          hangingIndent: hangingIndent,
          markerStyle: markerStyle,
        ),
        const SizedBox(width: 8),
        Expanded(child: content),
      ],
    );
  }
}

class _DocxListMarker extends StatelessWidget {
  final String marker;
  final double hangingIndent;
  final TextStyle markerStyle;

  const _DocxListMarker({
    required this.marker,
    required this.hangingIndent,
    required this.markerStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: hangingIndent),
      child: Text(
        marker,
        textAlign: TextAlign.right,
        softWrap: false,
        style: markerStyle,
      ),
    );
  }
}

class _DocxParagraphRichText extends StatelessWidget {
  final DocxParagraph paragraph;
  final TextStyle baseStyle;
  final double firstLineIndent;
  final ValueChanged<String>? onLinkTap;

  const _DocxParagraphRichText({
    required this.paragraph,
    required this.baseStyle,
    required this.firstLineIndent,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = paragraph.style;

    return RichText(
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
          if (paragraph.list == null && firstLineIndent > 0)
            WidgetSpan(child: SizedBox(width: firstLineIndent)),
          for (final run in paragraph.runs)
            _textSpanForRun(run, baseStyle, onLinkTap),
        ],
      ),
    );
  }
}

TextStyle _paragraphTextStyle(BuildContext context, DocxParagraph paragraph) {
  final normal = DefaultTextStyle.of(context).style.copyWith(
    fontSize: 14.6667,
    height: paragraph.style.lineHeight ?? 1.15,
  );

  final style = switch (paragraph.style.kind) {
    DocxBuiltinKind.title => normal.copyWith(
      fontSize: 37.3333,
      fontWeight: FontWeight.bold,
    ),
    DocxBuiltinKind.subtitle => normal.copyWith(
      fontSize: 16,
      fontStyle: FontStyle.italic,
    ),
    DocxBuiltinKind.heading1 => normal.copyWith(
      fontSize: 21.3333,
      fontWeight: FontWeight.bold,
    ),
    DocxBuiltinKind.heading2 => normal.copyWith(
      fontSize: 17.3333,
      fontWeight: FontWeight.bold,
    ),
    DocxBuiltinKind.heading3 => normal.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    _ => normal,
  };
  final lineSpacing = paragraph.style.lineSpacing;
  if (lineSpacing == null) {
    return style;
  }
  final height = lineSpacing / (style.fontSize ?? 14.6667);
  return style.copyWith(
    height: paragraph.style.lineSpacingAtLeast
        ? math.max(style.height ?? 1, height)
        : height,
  );
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
  final style = _runTextStyle(run, target);
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

TextStyle _runTextStyle(DocxTextRun run, String? target) {
  final runDecoration = _decoration(run.style);
  final runColor = run.style.color;
  final highlightColor = run.style.highlightColor;

  return TextStyle(
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
    color: runColor == null
        ? target == null
              ? null
              : Colors.blue
        : Color(runColor),
    backgroundColor: highlightColor == null ? null : Color(highlightColor),
    letterSpacing: run.style.allCaps || run.style.smallCaps ? 1.2 : null,
  );
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
      return const _DocxBrokenImage();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _DocxLinkedImage(image: image, onLinkTap: onLinkTap),
    );
  }
}

class _DocxLinkedImage extends StatelessWidget {
  final DocxImage image;
  final ValueChanged<String>? onLinkTap;

  const _DocxLinkedImage({required this.image, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    final href = image.href;
    final onTap = onLinkTap;
    final content = _DocxImageContent(image: image);

    if (href == null || onTap == null) {
      return content;
    }

    return GestureDetector(onTap: () => onTap(href), child: content);
  }
}

class _DocxImageContent extends StatelessWidget {
  final DocxImage image;

  const _DocxImageContent({required this.image});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: image.altText,
        image: true,
        child: Image.memory(
          image.bytes,
          key: const ValueKey('docx-image'),
          width: image.width,
          height: image.height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const _DocxBrokenImage(),
        ),
      ),
    );
  }
}

class _DocxBrokenImage extends StatelessWidget {
  const _DocxBrokenImage();

  @override
  Widget build(BuildContext context) {
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

class _DocxUnsupportedContentView extends StatelessWidget {
  const _DocxUnsupportedContentView({
    required this.content,
    required this.message,
  });

  final DocxUnsupportedContent content;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sourceWidth = content.width ?? 240;
          final sourceHeight = content.height ?? 120;
          final scale = constraints.maxWidth < sourceWidth
              ? constraints.maxWidth / sourceWidth
              : 1.0;
          return _DocxUnsupportedBox(
            message: message,
            width: sourceWidth * scale,
            height: math.min(sourceHeight * scale, 480),
          );
        },
      ),
    );
  }
}

class _DocxUnsupportedBox extends StatelessWidget {
  const _DocxUnsupportedBox({
    required this.message,
    required this.width,
    required this.height,
  });

  final String message;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('docx-unsupported-content'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_chart_outlined, color: colors.onSurfaceVariant),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

class _DocxTableView extends StatelessWidget {
  final DocxTable table;
  final FilePreviewKitTexts texts;
  final ValueChanged<String>? onLinkTap;

  const _DocxTableView({
    required this.table,
    required this.texts,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final columnCount = _tableColumnCount(table);

    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
            _DocxTableRowView(
              table: table,
              row: table.rows[rowIndex],
              rowIndex: rowIndex,
              columnCount: columnCount,
              texts: texts,
              onLinkTap: onLinkTap,
            ),
        ],
      ),
    );
  }
}

class _DocxTableRowView extends StatelessWidget {
  final DocxTable table;
  final DocxTableRow row;
  final int rowIndex;
  final int columnCount;
  final FilePreviewKitTexts texts;
  final ValueChanged<String>? onLinkTap;

  const _DocxTableRowView({
    required this.table,
    required this.row,
    required this.rowIndex,
    required this.columnCount,
    required this.texts,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    var columnIndex = 0;
    final children = <Widget>[];

    for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
      final cell = row.cells[cellIndex];
      if (cell.rowSpan > 0) {
        children.add(
          Expanded(
            flex: _cellFlex(cell, columnIndex),
            child: _buildCell(context, cell, cellIndex, row.isHeader),
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
            _DocxBlockView(block: block, texts: texts, onLinkTap: onLinkTap),
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
  final FilePreviewKitTexts texts;
  final ValueChanged<String>? onLinkTap;

  const _DocxReferencesView({
    required this.title,
    required this.entries,
    required this.texts,
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
          _DocxReferenceEntryView(
            entry: entry,
            texts: texts,
            onLinkTap: onLinkTap,
          ),
      ],
    );
  }
}

class _DocxReferenceEntryView extends StatelessWidget {
  final _DocxReferenceEntry entry;
  final FilePreviewKitTexts texts;
  final ValueChanged<String>? onLinkTap;

  const _DocxReferenceEntryView({
    required this.entry,
    required this.texts,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: Text(entry.label),
        ),
        Expanded(
          child: _DocxReferenceBlocks(
            blocks: entry.blocks,
            texts: texts,
            onLinkTap: onLinkTap,
          ),
        ),
      ],
    );
  }
}

class _DocxReferenceBlocks extends StatelessWidget {
  final List<DocxBlock> blocks;
  final FilePreviewKitTexts texts;
  final ValueChanged<String>? onLinkTap;

  const _DocxReferenceBlocks({
    required this.blocks,
    required this.texts,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks)
          _DocxBlockView(block: block, texts: texts, onLinkTap: onLinkTap),
      ],
    );
  }
}
