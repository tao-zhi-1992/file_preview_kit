import 'dart:typed_data';

class DocxDocument {
  final List<DocxBlock> blocks;

  const DocxDocument({required this.blocks});
}

sealed class DocxBlock {
  const DocxBlock();
}

class DocxParagraph extends DocxBlock {
  final List<DocxTextRun> runs;
  final DocxParagraphAlignment? alignment;
  final String? styleId;
  final DocxListInfo? list;
  final double? spacingBefore;
  final double? spacingAfter;
  final double? lineHeight;

  const DocxParagraph({
    required this.runs,
    this.alignment,
    this.styleId,
    this.list,
    this.spacingBefore,
    this.spacingAfter,
    this.lineHeight,
  });
}

class DocxTextRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final double? fontSize;
  final int? color;
  final int? highlightColor;

  const DocxTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.color,
    this.highlightColor,
  });
}

class DocxTable extends DocxBlock {
  final List<DocxTableRow> rows;
  final List<double?> columnWidths;
  final bool hasBorders;

  const DocxTable({
    required this.rows,
    this.columnWidths = const [],
    this.hasBorders = false,
  });
}

class DocxTableRow {
  final List<DocxTableCell> cells;

  const DocxTableRow({required this.cells});
}

class DocxTableCell {
  final List<DocxBlock> blocks;
  final int columnSpan;
  final double? width;

  const DocxTableCell({required this.blocks, this.columnSpan = 1, this.width});
}

class DocxImage extends DocxBlock {
  final Uint8List bytes;
  final String contentType;
  final double? width;
  final double? height;

  DocxImage({
    required this.bytes,
    required this.contentType,
    this.width,
    this.height,
  });
}

class DocxListInfo {
  final DocxListType type;
  final int level;
  final int? number;

  const DocxListInfo({required this.type, required this.level, this.number});
}

enum DocxParagraphAlignment { left, center, right, justify }

enum DocxListType { bullet, numbered }
