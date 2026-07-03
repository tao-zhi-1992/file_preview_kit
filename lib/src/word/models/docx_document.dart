import 'dart:typed_data';

class DocxDocument {
  final List<DocxBlock> blocks;
  final List<DocxNote> notes;
  final List<DocxComment> comments;

  const DocxDocument({
    required this.blocks,
    this.notes = const [],
    this.comments = const [],
  });
}

sealed class DocxBlock {
  const DocxBlock();
}

// ---------------------------------------------------------------------------
// Text style
// ---------------------------------------------------------------------------

enum DocxVerticalAlignment { baseline, superscript, subscript }

class DocxTextStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool allCaps;
  final bool smallCaps;
  final double? fontSize;
  final int? color;
  final int? highlightColor;
  final String? fontFamily;
  final DocxVerticalAlignment? verticalAlignment;

  const DocxTextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.allCaps = false,
    this.smallCaps = false,
    this.fontSize,
    this.color,
    this.highlightColor,
    this.fontFamily,
    this.verticalAlignment,
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
  final String? styleName;
  final DocxBuiltinKind kind;
  final DocxParagraphAlignment? align;
  final double? spacingBefore;
  final double? spacingAfter;
  final double? lineHeight;
  final double? lineSpacing;
  final double? indentStart;
  final double? indentEnd;
  final double? firstLineIndent;
  final double? hangingIndent;

  const DocxParagraphStyle({
    this.styleId,
    this.styleName,
    this.kind = DocxBuiltinKind.none,
    this.align,
    this.spacingBefore,
    this.spacingAfter,
    this.lineHeight,
    this.lineSpacing,
    this.indentStart,
    this.indentEnd,
    this.firstLineIndent,
    this.hangingIndent,
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
  final String? styleId;
  final String? styleName;
  final String? href;
  final String? anchor;

  const DocxTextRun({
    required this.text,
    this.style = const DocxTextStyle(),
    this.styleId,
    this.styleName,
    this.href,
    this.anchor,
  });
}

// ---------------------------------------------------------------------------
// Hyperlink block (standalone, for block-level hyperlinks)
// ---------------------------------------------------------------------------

class DocxHyperlink extends DocxBlock {
  final String? href;
  final String? anchor;
  final List<DocxTextRun> runs;

  const DocxHyperlink({this.href, this.anchor, required this.runs});
}

// ---------------------------------------------------------------------------
// Break block
// ---------------------------------------------------------------------------

enum DocxBreakType { page, column }

class DocxBreak extends DocxBlock {
  final DocxBreakType breakType;

  const DocxBreak({required this.breakType});
}

// ---------------------------------------------------------------------------
// Bookmark
// ---------------------------------------------------------------------------

class DocxBookmarkStart extends DocxBlock {
  final String name;

  const DocxBookmarkStart({required this.name});
}

// ---------------------------------------------------------------------------
// Table block
// ---------------------------------------------------------------------------

class DocxTable extends DocxBlock {
  final List<DocxTableRow> rows;
  final String? styleId;
  final String? styleName;
  final List<double?> columnWidths;
  final bool hasBorders;

  const DocxTable({
    required this.rows,
    this.styleId,
    this.styleName,
    this.columnWidths = const [],
    this.hasBorders = false,
  });
}

class DocxTableRow {
  final List<DocxTableCell> cells;
  final bool isHeader;

  const DocxTableRow({required this.cells, this.isHeader = false});
}

class DocxTableCell {
  final List<DocxBlock> blocks;
  final int columnSpan;
  final int rowSpan;
  final double? width;

  const DocxTableCell({
    required this.blocks,
    this.columnSpan = 1,
    this.rowSpan = 1,
    this.width,
  });
}

// ---------------------------------------------------------------------------
// Image block
// ---------------------------------------------------------------------------

class DocxImage extends DocxBlock {
  final Uint8List bytes;
  final String contentType;
  final double? width;
  final double? height;
  final String? altText;
  final String? href;

  DocxImage({
    required this.bytes,
    required this.contentType,
    this.width,
    this.height,
    this.altText,
    this.href,
  });
}

// ---------------------------------------------------------------------------
// Notes and comments
// ---------------------------------------------------------------------------

enum DocxNoteType { footnote, endnote }

class DocxNote {
  final String id;
  final DocxNoteType type;
  final List<DocxBlock> blocks;

  const DocxNote({required this.id, required this.type, required this.blocks});
}

class DocxComment {
  final String id;
  final String? authorName;
  final String? authorInitials;
  final List<DocxBlock> blocks;

  const DocxComment({
    required this.id,
    this.authorName,
    this.authorInitials,
    required this.blocks,
  });
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

class DocxListInfo {
  final DocxListType type;
  final int level;
  final int? number;
  final String? marker;
  final double? indentStart;
  final double? hangingIndent;

  const DocxListInfo({
    required this.type,
    required this.level,
    this.number,
    this.marker,
    this.indentStart,
    this.hangingIndent,
  });
}

enum DocxParagraphAlignment { left, center, right, justify }

enum DocxListType { bullet, numbered }
