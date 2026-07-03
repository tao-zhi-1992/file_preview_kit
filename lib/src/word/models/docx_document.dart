import 'dart:typed_data';

class DocxDocument {
  final List<DocxBlock> blocks;

  const DocxDocument({required this.blocks});
}

sealed class DocxBlock {
  const DocxBlock();
}

// ---------------------------------------------------------------------------
// Text style
// ---------------------------------------------------------------------------

class DocxTextStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final double? fontSize;
  final int? color;
  final int? highlightColor;

  const DocxTextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.color,
    this.highlightColor,
  });
}

// ---------------------------------------------------------------------------
// Paragraph style
// ---------------------------------------------------------------------------

enum DocxBuiltinKind {
  title,
  subtitle,
  heading1,
  heading2,
  heading3,
  normal,
  none,
}

class DocxParagraphStyle {
  final String? styleId;
  final DocxBuiltinKind kind;
  final DocxParagraphAlignment? align;
  final double? spacingBefore;
  final double? spacingAfter;
  final double? lineHeight;

  const DocxParagraphStyle({
    this.styleId,
    this.kind = DocxBuiltinKind.none,
    this.align,
    this.spacingBefore,
    this.spacingAfter,
    this.lineHeight,
  });
}

// ---------------------------------------------------------------------------
// Paragraph block
// ---------------------------------------------------------------------------

class DocxParagraph extends DocxBlock {
  final List<DocxTextRun> runs;
  final DocxParagraphStyle style;
  final DocxListInfo? list;

  const DocxParagraph({
    required this.runs,
    this.style = const DocxParagraphStyle(),
    this.list,
  });
}

class DocxTextRun {
  final String text;
  final DocxTextStyle style;

  const DocxTextRun({
    required this.text,
    this.style = const DocxTextStyle(),
  });
}

// ---------------------------------------------------------------------------
// Table block
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Image block
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class DocxListInfo {
  final DocxListType type;
  final int level;
  final int? number;

  const DocxListInfo({required this.type, required this.level, this.number});
}

enum DocxParagraphAlignment { left, center, right, justify }

enum DocxListType { bullet, numbered }
