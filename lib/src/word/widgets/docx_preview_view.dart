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

    return Padding(
      padding: EdgeInsets.only(left: (list?.level ?? 0) * 20, bottom: 8),
      child: RichText(
        textAlign: switch (paragraph.alignment) {
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
                    ? '• '
                    : '${list.number ?? 1}. ',
              ),
            for (final run in paragraph.runs)
              TextSpan(
                text: run.text,
                style: TextStyle(
                  fontWeight: run.bold ? FontWeight.bold : null,
                  fontStyle: run.italic ? FontStyle.italic : null,
                  decoration: run.underline ? TextDecoration.underline : null,
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
    ).style.copyWith(fontSize: 16, height: 1.5);
    final styleId = paragraph.styleId?.toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );

    return switch (styleId) {
      'heading1' => normal.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
      'heading2' => normal.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      'heading3' => normal.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      _ => normal,
    };
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
    final columnCount = table.rows.fold<int>(
      0,
      (count, row) => row.cells.length > count ? row.cells.length : count,
    );

    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Table(
        border: TableBorder.all(color: Theme.of(context).dividerColor),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          for (final row in table.rows)
            TableRow(
              children: [
                for (var index = 0; index < columnCount; index++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: index < row.cells.length
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final block in row.cells[index].blocks)
                                _DocxBlockView(block: block),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
