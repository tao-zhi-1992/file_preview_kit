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

  const DocxParagraph({
    required this.runs,
    this.alignment,
    this.styleId,
    this.list,
  });
}

class DocxTextRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  const DocxTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });
}

class DocxTable extends DocxBlock {
  final List<DocxTableRow> rows;

  const DocxTable({required this.rows});
}

class DocxTableRow {
  final List<DocxTableCell> cells;

  const DocxTableRow({required this.cells});
}

class DocxTableCell {
  final List<DocxBlock> blocks;

  const DocxTableCell({required this.blocks});
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
