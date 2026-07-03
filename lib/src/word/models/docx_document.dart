import 'dart:typed_data';

/// Parsed content and references from a DOCX package.
class DocxDocument {
  final List<DocxBlock> blocks;
  final List<DocxNote> notes;
  final List<DocxComment> comments;

  /// Creates a document from block content and optional references.
  const DocxDocument({
    required this.blocks,
    this.notes = const [],
    this.comments = const [],
  });
}

/// Base type for renderable DOCX blocks.
sealed class DocxBlock {
  const DocxBlock();
}

// ---------------------------------------------------------------------------
// Text style
// ---------------------------------------------------------------------------

/// Vertical placement of text relative to the baseline.
enum DocxVerticalAlignment { baseline, superscript, subscript }

/// Resolved formatting for a text run.
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

  /// Creates text formatting with optional DOCX properties.
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

/// Recognized built-in paragraph style categories.
enum DocxBuiltinKind {
  title,
  subtitle,
  heading1,
  heading2,
  heading3,
  normal,
  none,
}

/// Resolved formatting and layout for a paragraph.
class DocxParagraphStyle {
  final String? styleId;
  final String? styleName;
  final DocxBuiltinKind kind;
  final DocxParagraphAlignment? align;
  final double? spacingBefore;
  final double? spacingAfter;
  final double? lineHeight;
  final double? lineSpacing;
  final bool lineSpacingAtLeast;
  final double? indentStart;
  final double? indentEnd;
  final double? firstLineIndent;
  final double? hangingIndent;

  /// Creates paragraph formatting with optional DOCX properties.
  const DocxParagraphStyle({
    this.styleId,
    this.styleName,
    this.kind = DocxBuiltinKind.none,
    this.align,
    this.spacingBefore,
    this.spacingAfter,
    this.lineHeight,
    this.lineSpacing,
    this.lineSpacingAtLeast = false,
    this.indentStart,
    this.indentEnd,
    this.firstLineIndent,
    this.hangingIndent,
  });
}

// ---------------------------------------------------------------------------
// Paragraph block
// ---------------------------------------------------------------------------

/// A paragraph containing styled text runs.
class DocxParagraph extends DocxBlock {
  final List<DocxTextRun> runs;
  final DocxParagraphStyle style;
  final DocxListInfo? list;

  /// Creates a paragraph.
  const DocxParagraph({
    required this.runs,
    this.style = const DocxParagraphStyle(),
    this.list,
  });
}

/// A contiguous piece of text with shared formatting.
class DocxTextRun {
  final String text;
  final DocxTextStyle style;
  final String? styleId;
  final String? styleName;
  final String? href;
  final String? anchor;

  /// Creates a text run.
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

/// A block-level hyperlink containing styled text runs.
class DocxHyperlink extends DocxBlock {
  final String? href;
  final String? anchor;
  final List<DocxTextRun> runs;

  /// Creates a block-level hyperlink.
  const DocxHyperlink({this.href, this.anchor, required this.runs});
}

// ---------------------------------------------------------------------------
// Break block
// ---------------------------------------------------------------------------

/// Explicit break categories found in DOCX content.
enum DocxBreakType { page, column }

/// An explicit page or column break.
class DocxBreak extends DocxBlock {
  final DocxBreakType breakType;

  /// Creates an explicit break.
  const DocxBreak({required this.breakType});
}

// ---------------------------------------------------------------------------
// Bookmark
// ---------------------------------------------------------------------------

/// Marks the start of a named DOCX bookmark.
class DocxBookmarkStart extends DocxBlock {
  final String name;

  /// Creates a bookmark marker.
  const DocxBookmarkStart({required this.name});
}

// ---------------------------------------------------------------------------
// Table block
// ---------------------------------------------------------------------------

/// A table with rows, style metadata, and optional column widths.
class DocxTable extends DocxBlock {
  final List<DocxTableRow> rows;
  final String? styleId;
  final String? styleName;
  final List<double?> columnWidths;
  final bool hasBorders;

  /// Creates a table.
  const DocxTable({
    required this.rows,
    this.styleId,
    this.styleName,
    this.columnWidths = const [],
    this.hasBorders = false,
  });
}

/// A row in a DOCX table.
class DocxTableRow {
  final List<DocxTableCell> cells;
  final bool isHeader;

  /// Creates a table row.
  const DocxTableRow({required this.cells, this.isHeader = false});
}

/// A table cell containing block content.
class DocxTableCell {
  final List<DocxBlock> blocks;
  final int columnSpan;
  final int rowSpan;
  final double? width;

  /// Creates a table cell.
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

/// An image extracted from DOCX content.
class DocxImage extends DocxBlock {
  final Uint8List bytes;
  final String contentType;
  final double? width;
  final double? height;
  final String? altText;
  final String? href;

  /// Creates an image block.
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

/// Reference note categories.
enum DocxNoteType { footnote, endnote }

/// A footnote or endnote extracted from a document.
class DocxNote {
  final String id;
  final DocxNoteType type;
  final List<DocxBlock> blocks;

  /// Creates a document note.
  const DocxNote({required this.id, required this.type, required this.blocks});
}

/// A document comment and its author metadata.
class DocxComment {
  final String id;
  final String? authorName;
  final String? authorInitials;
  final List<DocxBlock> blocks;

  /// Creates a document comment.
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

/// Numbering and indentation metadata for a list paragraph.
class DocxListInfo {
  final DocxListType type;
  final int level;
  final int? number;
  final String? marker;
  final double? indentStart;
  final double? hangingIndent;

  /// Creates list metadata.
  const DocxListInfo({
    required this.type,
    required this.level,
    this.number,
    this.marker,
    this.indentStart,
    this.hangingIndent,
  });
}

/// Supported paragraph alignment values.
enum DocxParagraphAlignment { left, center, right, justify }

/// Supported list marker categories.
enum DocxListType { bullet, numbered }
