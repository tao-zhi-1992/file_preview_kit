import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/preview_exception.dart';
import '../models/docx_document.dart';

const _emuPerLogicalPixel = 9525;

/// Maps from character codes in the Symbol/Wingdings fonts to Unicode.
/// Only the most common mappings used in real-world documents.
const _symbolFontMap = {
  'Symbol': <int, String>{
    0x28: '\u2190', // ←
    0x29: '\u2192', // →
    0x2A: '\u2194', // ↔
    0x2B: '\u2191', // ↑
    0x2C: '\u2193', // ↓
    0x2D: '\u2195', // ↕
    0x2E: '\u21D0', // ⇐
    0x2F: '\u21D2', // ⇒
    0x30: '\u21D4', // ⇔
    0x31: '\u21D1', // ⇑
    0x32: '\u21D3', // ⇓
    0x33: '\u21D5', // ⇕
    0x34: '\u2196', // ↖
    0x35: '\u2197', // ↗
    0x36: '\u2198', // ↘
    0x37: '\u2199', // ↙
    0x38: '\u21A6', // ↦
    0x39: '\u21A8', // ↨
    0x3A: '\u21A9', // ↩
    0x3B: '\u21AA', // ↪
    0x41: '\u0391', // Α
    0x42: '\u0392', // Β
    0x43: '\u03A7', // Χ
    0x44: '\u0394', // Δ
    0x45: '\u0395', // Ε
    0x46: '\u03A6', // Φ
    0x47: '\u0393', // Γ
    0x48: '\u0397', // Η
    0x49: '\u0399', // Ι
    0x4A: '\u03D1', // ϑ
    0x4B: '\u039A', // Κ
    0x4C: '\u039B', // Λ
    0x4D: '\u039C', // Μ
    0x4E: '\u039D', // Ν
    0x4F: '\u039F', // Ο
    0x50: '\u03A0', // Π
    0x51: '\u0398', // Θ
    0x52: '\u03A1', // Ρ
    0x53: '\u03A3', // Σ
    0x54: '\u03A4', // Τ
    0x55: '\u03A5', // Υ
    0x56: '\u03C2', // ς
    0x57: '\u03A9', // Ω
    0x58: '\u039E', // Ξ
    0x59: '\u03A8', // Ψ
    0x5A: '\u0396', // Ζ
    0x61: '\u03B1', // α
    0x62: '\u03B2', // β
    0x63: '\u03C7', // χ
    0x64: '\u03B4', // δ
    0x65: '\u03B5', // ε
    0x66: '\u03C6', // φ
    0x67: '\u03B3', // γ
    0x68: '\u03B7', // η
    0x69: '\u03B9', // ι
    0x6A: '\u03D5', // ϕ
    0x6B: '\u03BA', // κ
    0x6C: '\u03BB', // λ
    0x6D: '\u03BC', // μ
    0x6E: '\u03BD', // ν
    0x6F: '\u03BF', // ο
    0x70: '\u03C0', // π
    0x71: '\u03B8', // θ
    0x72: '\u03C1', // ρ
    0x73: '\u03C3', // σ
    0x74: '\u03C4', // τ
    0x75: '\u03C5', // υ
    0x76: '\u03C0', // ω (approximation)
    0x77: '\u03C9', // ω
    0x78: '\u03BE', // ξ
    0x79: '\u03C8', // ψ
    0x7A: '\u03B6', // ζ
    0x7F: '\u221E', // ∞
    0x80: '\u2202', // ∂
    0x81: '\u0394', // Δ
    0x82: '\u2211', // ∑
    0x83: '\u220F', // ∏
    0x84: '\u03C0', // π
    0x85: '\u222B', // ∫
    0x86: '\u222A', // ∪
    0x87: '\u2283', // ⊃
    0x88: '\u2282', // ⊂
    0x89: '\u2286', // ⊆
    0x8A: '\u2287', // ⊇
    0x8B: '\u2229', // ∩
    0x8C: '\u2228', // ∨
    0x8D: '\u2227', // ∧
    0x8E: '\u00AC', // ¬
    0x8F: '\u2208', // ∈
    0x90: '\u00D7', // ×
    0xB0: '\u2660', // ♠
    0xB1: '\u2665', // ♥
    0xB2: '\u2666', // ♦
    0xB3: '\u2663', // ♣
  },
};

class DocxParser {
  DocxDocument parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const EmptyFileException();
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = _readArchiveText(archive, 'word/document.xml');

      if (documentXml == null) {
        throw const InvalidDocxException();
      }

      final document = XmlDocument.parse(documentXml);
      final body = _firstDescendant(document, 'body');

      if (body == null) {
        throw const InvalidDocxException();
      }

      final state = _ParseState(
        archive: archive,
        relationships: _parseRelationships(
          _readArchiveText(archive, 'word/_rels/document.xml.rels'),
        ),
        contentTypes: _parseContentTypes(
          _readArchiveText(archive, '[Content_Types].xml'),
        ),
        numbering: _parseNumbering(
          _readArchiveText(archive, 'word/numbering.xml'),
        ),
        styles: _parseStyles(_readArchiveText(archive, 'word/styles.xml')),
        numberingCounters: <int, Map<int, int>>{},
      );

      return DocxDocument(blocks: _parseBlocks(body, state));
    } on PreviewException {
      rethrow;
    } catch (_) {
      throw const InvalidDocxException();
    }
  }

  // -----------------------------------------------------------------------
  // Block parsing
  // -----------------------------------------------------------------------

  List<DocxBlock> _parseBlocks(XmlElement parent, _ParseState state) {
    final blocks = <DocxBlock>[];

    for (final child in parent.childElements) {
      switch (child.name.local) {
        case 'p':
          blocks.addAll(_parseParagraph(child, state));
        case 'tbl':
          blocks.add(_parseTable(child, state));
        case 'bookmarkStart':
          // Ignored for preview; no visible content
          break;
        case 'sectPr':
          // Section properties; ignored for preview
          break;
      }
    }

    return blocks;
  }

  // -----------------------------------------------------------------------
  // Paragraph parsing
  // -----------------------------------------------------------------------

  List<DocxBlock> _parseParagraph(XmlElement paragraph, _ParseState state) {
    final paragraphProperties = _directChild(paragraph, 'pPr');
    final styleId = _attribute(
      paragraphProperties == null
          ? null
          : _directChild(paragraphProperties, 'pStyle'),
      'val',
    );

    // Resolve the effective style from styles.xml if available.
    final resolvedStyle = state.styles.resolveParagraphStyle(styleId);
    final kind = _parseBuiltinKind(resolvedStyle?.styleId ?? styleId);

    final justification = paragraphProperties == null
        ? null
        : _directChild(paragraphProperties, 'jc');
    final spacing = paragraphProperties == null
        ? null
        : _directChild(paragraphProperties, 'spacing');
    final alignment = _parseAlignment(_attribute(justification, 'val'));
    final spacingBefore = _twipsToPixels(_attribute(spacing, 'before'));
    final spacingAfter = _twipsToPixels(_attribute(spacing, 'after'));
    final lineHeight = _lineHeight(_attribute(spacing, 'line'));

    final paragraphStyle = DocxParagraphStyle(
      styleId: resolvedStyle?.styleId ?? styleId,
      kind: kind,
      align: alignment,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
      lineHeight: lineHeight,
    );

    var list = _parseList(paragraphProperties, state);
    final blocks = <DocxBlock>[];
    final runs = <DocxTextRun>[];

    void addParagraph({bool evenWhenEmpty = false}) {
      if (runs.isEmpty && !evenWhenEmpty) {
        return;
      }

      blocks.add(
        DocxParagraph(runs: List.of(runs), style: paragraphStyle, list: list),
      );
      runs.clear();
      list = null;
    }

    void addBlock(DocxBlock block) {
      if (runs.isNotEmpty) {
        addParagraph();
      }
      blocks.add(block);
    }

    for (final child in paragraph.childElements) {
      switch (child.name.local) {
        case 'r':
          _parseRun(
            child,
            state,
            runs,
            blocks,
            addParagraph,
            addBlock,
            list != null && runs.isEmpty && blocks.isEmpty,
          );
          break;
        case 'hyperlink':
          _parseHyperlink(child, state, runs, blocks, paragraphStyle, list,
              addParagraph, addBlock);
          break;
        case 'bookmarkStart':
          // No visible content in preview
          break;
        case 'pPr':
          // Already handled above
          break;
        case 'rPr':
          // Paragraph-level run properties (e.g., w:del) — ignored
          break;
        default:
          // Recursively look for runs inside unknown containers (e.g. w:ins)
          for (final inner in _wordRuns(child)) {
            _parseRun(
              inner,
              state,
              runs,
              blocks,
              addParagraph,
              addBlock,
              list != null && runs.isEmpty && blocks.isEmpty,
            );
          }
          break;
      }
    }

    addParagraph(evenWhenEmpty: blocks.isEmpty);
    return blocks;
  }

  void _parseRun(
    XmlElement run,
    _ParseState state,
    List<DocxTextRun> runs,
    List<DocxBlock> blocks,
    void Function({bool evenWhenEmpty}) addParagraph,
    void Function(DocxBlock) addBlock,
    bool hasList,
  ) {
    final properties = _directChild(run, 'rPr');
    final textStyle = _readRunStyle(properties, state.styles);
    final text = StringBuffer();

    void addTextRun() {
      if (text.isEmpty) {
        return;
      }

      runs.add(DocxTextRun(text: text.toString(), style: textStyle));
      text.clear();
    }

    for (final child in run.childElements) {
      switch (child.name.local) {
        case 't':
          text.write(child.innerText);
        case 'br':
          final breakType = _attribute(child, 'type');
          if (breakType == 'page') {
            addTextRun();
            addBlock(const DocxBreak(breakType: DocxBreakType.page));
          } else if (breakType == 'column') {
            addTextRun();
            addBlock(const DocxBreak(breakType: DocxBreakType.column));
          } else {
            text.write('\n');
          }
        case 'tab':
          text.write('\t');
        case 'noBreakHyphen':
          text.write('\u2011');
        case 'softHyphen':
          text.write('\u00AD');
        case 'sym':
          text.write(_parseSymbol(child));
        case 'drawing':
          addTextRun();

          // Only emit an empty paragraph when there is a pending list, so
          // that list numbering resumes after the image.
          if (hasList) {
            addParagraph(evenWhenEmpty: true);
          } else {
            addParagraph();
          }

          blocks.addAll(_parseImages(child, state));
      }
    }

    addTextRun();
  }

  void _parseHyperlink(
    XmlElement element,
    _ParseState state,
    List<DocxTextRun> runs,
    List<DocxBlock> blocks,
    DocxParagraphStyle paragraphStyle,
    DocxListInfo? list,
    void Function({bool evenWhenEmpty}) addParagraph,
    void Function(DocxBlock) addBlock,
  ) {
    final relationshipId = _attribute(element, 'id');
    final anchor = _attribute(element, 'anchor');
    String? href;

    if (relationshipId != null) {
      final relationship = state.relationships[relationshipId];
      if (relationship != null && !relationship.external) {
        href = relationship.target;
      } else if (relationship != null) {
        href = relationship.target;
      }
    }

    final hyperlinkRuns = <DocxTextRun>[];

    for (final child in element.childElements) {
      if (child.name.local == 'r') {
        final properties = _directChild(child, 'rPr');
        final textStyle = _readRunStyle(properties, state.styles);
        final text = StringBuffer();

        for (final inner in child.childElements) {
          if (inner.name.local == 't') {
            text.write(inner.innerText);
          } else if (inner.name.local == 'br') {
            text.write('\n');
          } else if (inner.name.local == 'tab') {
            text.write('\t');
          } else if (inner.name.local == 'noBreakHyphen') {
            text.write('\u2011');
          } else if (inner.name.local == 'softHyphen') {
            text.write('\u00AD');
          } else if (inner.name.local == 'sym') {
            text.write(_parseSymbol(inner));
          }
        }

        if (text.isNotEmpty) {
          hyperlinkRuns.add(
            DocxTextRun(text: text.toString(), style: textStyle),
          );
        }
      }
    }

    if (hyperlinkRuns.isNotEmpty) {
      // If there were preceding runs in the paragraph, emit them first.
      if (runs.isNotEmpty) {
        addParagraph();
      }
      blocks.add(DocxHyperlink(href: href, anchor: anchor, runs: hyperlinkRuns));
    }
  }

  DocxTextStyle _readRunStyle(
    XmlElement? properties,
    _DocxStyles styles,
  ) {
    if (properties == null) {
      return const DocxTextStyle();
    }

    // Resolve character style if present.
    final styleId = _attribute(_directChild(properties, 'rStyle'), 'val');
    final charStyle = styleId != null ? styles.findCharacterStyle(styleId) : null;

    return DocxTextStyle(
      bold: _isEnabled(properties, 'b') || (charStyle?.bold ?? false),
      italic: _isEnabled(properties, 'i') || (charStyle?.italic ?? false),
      underline: _isUnderline(properties) || (charStyle?.underline ?? false),
      strike: _isEnabled(properties, 'strike') || (charStyle?.strike ?? false),
      allCaps: _isEnabled(properties, 'caps') || (charStyle?.allCaps ?? false),
      smallCaps:
          _isEnabled(properties, 'smallCaps') || (charStyle?.smallCaps ?? false),
      fontSize: _halfPoints(
            _attribute(
              _directChild(properties, 'sz'),
              'val',
            ),
          ) ??
          charStyle?.fontSize,
      color: _hexColor(
            _attribute(
              _directChild(properties, 'color'),
              'val',
            ),
          ) ??
          charStyle?.color,
      highlightColor: _highlightColor(
            _attribute(
              _directChild(properties, 'highlight'),
              'val',
            ),
          ) ??
          charStyle?.highlightColor,
      fontFamily:
          _attribute(_directChild(properties, 'rFonts'), 'ascii') ??
              charStyle?.fontFamily,
      verticalAlignment: _parseVerticalAlignment(
        _attribute(_directChild(properties, 'vertAlign'), 'val'),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Image parsing
  // -----------------------------------------------------------------------

  List<DocxImage> _parseImages(XmlElement drawing, _ParseState state) {
    final extent = _firstDescendant(drawing, 'extent');
    final width = _emuToPixels(_attribute(extent, 'cx'));
    final height = _emuToPixels(_attribute(extent, 'cy'));
    final images = <DocxImage>[];

    for (final element in drawing.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'blip') {
        continue;
      }

      final relationshipId =
          _attribute(element, 'embed') ?? _attribute(element, 'link');
      final relationship = state.relationships[relationshipId];
      final path = relationship == null || relationship.external
          ? null
          : _resolveWordPath(relationship.target);
      final bytes = path == null
          ? null
          : _readArchiveBytes(state.archive, path);

      images.add(
        DocxImage(
          bytes: bytes ?? Uint8List(0),
          contentType: path == null
              ? 'application/octet-stream'
              : state.contentTypes.typeFor(path),
          width: width,
          height: height,
        ),
      );
    }

    if (images.isEmpty) {
      images.add(
        DocxImage(
          bytes: Uint8List(0),
          contentType: 'application/octet-stream',
          width: width,
          height: height,
        ),
      );
    }

    return images;
  }

  // -----------------------------------------------------------------------
  // List / numbering
  // -----------------------------------------------------------------------

  DocxListInfo? _parseList(
    XmlElement? paragraphProperties,
    _ParseState state,
  ) {
    if (paragraphProperties == null) {
      return null;
    }

    final numberingProperties = _directChild(paragraphProperties, 'numPr');

    if (numberingProperties == null) {
      return null;
    }

    final level =
        int.tryParse(
          _attribute(_directChild(numberingProperties, 'ilvl'), 'val') ?? '',
        ) ??
        0;
    final numberId = int.tryParse(
      _attribute(_directChild(numberingProperties, 'numId'), 'val') ?? '',
    );
    final definition = numberId == null
        ? null
        : state.numbering[numberId]?[level];
    final type = definition?.type ?? DocxListType.bullet;

    if (type == DocxListType.bullet || numberId == null) {
      return DocxListInfo(type: type, level: level);
    }

    final counters =
        state.numberingCounters.putIfAbsent(numberId, () => <int, int>{});
    counters.removeWhere((counterLevel, _) => counterLevel > level);
    final number = (counters[level] ?? (definition?.start ?? 1) - 1) + 1;
    counters[level] = number;

    return DocxListInfo(type: type, level: level, number: number);
  }

  // -----------------------------------------------------------------------
  // Table parsing
  // -----------------------------------------------------------------------

  DocxTable _parseTable(XmlElement table, _ParseState state) {
    final tableProperties = _directChild(table, 'tblPr');
    final borders = tableProperties == null
        ? null
        : _directChild(tableProperties, 'tblBorders');
    final grid = _directChild(table, 'tblGrid');
    final columnWidths = grid == null
        ? <double?>[]
        : [
            for (final column in grid.childElements.where(
              (element) => element.name.local == 'gridCol',
            ))
              _twipsToPixels(_attribute(column, 'w')),
          ];

    // Track vertical merges keyed by (column start index).
    // Value = the _CellBuilder whose rowSpan we need to increase.
    final activeVMerges = <int, _CellBuilder>{};
    final rows = <_ParsedRow>[];

    for (final row in table.childElements.where((e) => e.name.local == 'tr')) {
      final rowProperties = _directChild(row, 'trPr');
      final isHeader = rowProperties != null &&
          _directChild(rowProperties, 'tblHeader') != null;
      final cells = <_CellBuilder>[];
      var columnCursor = 0;

      // Skip columns that are currently covered by an active vertical merge.
      while (activeVMerges.containsKey(columnCursor)) {
        final mergeCell = activeVMerges[columnCursor]!;
        // Increase rowSpan of the originating cell.
        mergeCell._rowSpan++;
        columnCursor += mergeCell.columnSpan;
      }

      for (final cell
          in row.childElements.where((e) => e.name.local == 'tc')) {
        // Advance cursor past any remaining vMerge gaps.
        while (activeVMerges.containsKey(columnCursor)) {
          final mergeCell = activeVMerges[columnCursor]!;
          mergeCell._rowSpan++;
          columnCursor += mergeCell.columnSpan;
        }

        final cellProperties = _directChild(cell, 'tcPr');
        final span =
            int.tryParse(
              _attribute(
                    cellProperties == null
                        ? null
                        : _directChild(cellProperties, 'gridSpan'),
                    'val',
                  ) ??
                  '',
                ) ??
                1;
        final widthElement = cellProperties == null
            ? null
            : _directChild(cellProperties, 'tcW');
        final width = _attribute(widthElement, 'type') == 'dxa'
            ? _twipsToPixels(_attribute(widthElement, 'w'))
            : null;
        final vMerge = _readVMerge(cellProperties);

        final cellBuilder = _CellBuilder(
          blocks: _parseBlocks(cell, state),
          columnSpan: span < 1 ? 1 : span,
          width: width,
        );

        if (vMerge == _VMerge.continue_) {
          // This cell is merged with the cell above. Skip it and extend the
          // active merge's rowSpan.
          final activeCell = activeVMerges[columnCursor];
          if (activeCell != null) {
            activeCell._rowSpan++;
          }
          // Do NOT add cellBuilder to cells. Remove active vMerge tracking
          // for this column range since the merge is now counted.
        } else if (vMerge == _VMerge.restart) {
          // Start a new vertical merge group.
          for (var c = columnCursor;
              c < columnCursor + cellBuilder.columnSpan;
              c++) {
            activeVMerges[c] = cellBuilder;
          }
          cells.add(cellBuilder);
        } else {
          // No vertical merge – clear any stale tracking in this range.
          for (var c = columnCursor;
              c < columnCursor + cellBuilder.columnSpan;
              c++) {
            activeVMerges.remove(c);
          }
          cells.add(cellBuilder);
        }

        columnCursor += cellBuilder.columnSpan;
      }

      rows.add(_ParsedRow(cells: cells, isHeader: isHeader));
    }

    return DocxTable(
      rows: [
        for (final r in rows)
          DocxTableRow(
            cells: [
              for (final c in r.cells)
                DocxTableCell(
                  blocks: c.blocks,
                  columnSpan: c.columnSpan,
                  rowSpan: c._rowSpan,
                  width: c.width,
                ),
            ],
            isHeader: r.isHeader,
          ),
      ],
      columnWidths: columnWidths,
      hasBorders:
          borders != null &&
          borders.childElements.any((border) {
            final value = _attribute(border, 'val');
            return value != 'nil' && value != 'none';
          }),
    );
  }

  // -----------------------------------------------------------------------
  // Cell vertical merge handling
  // -----------------------------------------------------------------------

  _VMerge? _readVMerge(XmlElement? cellProperties) {
    if (cellProperties == null) {
      return null;
    }

    final element = _directChild(cellProperties, 'vMerge');
    if (element == null) {
      return null;
    }

    final val = _attribute(element, 'val');
    if (val == 'continue') {
      return _VMerge.continue_;
    }
    return _VMerge.restart;
  }

  // -----------------------------------------------------------------------
  // Style resolution helpers
  // -----------------------------------------------------------------------

  Iterable<XmlElement> _wordRuns(XmlElement paragraph) sync* {
    for (final child in paragraph.childElements) {
      if (child.name.local == 'r') {
        yield child;
      } else if (child.name.local != 'pPr' &&
          child.name.local != 'drawing' &&
          child.name.local != 'hyperlink') {
        yield* _wordRuns(child);
      }
    }
  }

  // -----------------------------------------------------------------------
  // Archive reading
  // -----------------------------------------------------------------------

  String? _readArchiveText(Archive archive, String path) {
    final bytes = _readArchiveBytes(archive, path);
    return bytes == null ? null : utf8.decode(bytes);
  }

  Uint8List? _readArchiveBytes(Archive archive, String path) {
    for (final file in archive.files) {
      if (file.name == path && file.content is List<int>) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }

    return null;
  }

  // -----------------------------------------------------------------------
  // XML helpers
  // -----------------------------------------------------------------------

  XmlElement? _firstDescendant(XmlNode node, String localName) {
    for (final descendant in node.descendants.whereType<XmlElement>()) {
      if (descendant.name.local == localName) {
        return descendant;
      }
    }

    return null;
  }

  XmlElement? _directChild(XmlElement parent, String localName) {
    for (final child in parent.childElements) {
      if (child.name.local == localName) {
        return child;
      }
    }

    return null;
  }

  String? _attribute(XmlElement? element, String localName) {
    if (element == null) {
      return null;
    }

    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) {
        return attribute.value;
      }
    }

    return null;
  }

  // -----------------------------------------------------------------------
  // Value parsing
  // -----------------------------------------------------------------------

  bool _isEnabled(XmlElement? properties, String localName) {
    if (properties == null) {
      return false;
    }

    final property = _directChild(properties, localName);

    if (property == null) {
      return false;
    }

    final value = _attribute(property, 'val')?.toLowerCase();
    return value != '0' &&
        value != 'false' &&
        value != 'off' &&
        value != 'none';
  }

  bool _isUnderline(XmlElement? properties) {
    if (properties == null) {
      return false;
    }

    final property = _directChild(properties, 'u');
    if (property == null) {
      return false;
    }

    final value = _attribute(property, 'val');
    return value != null &&
        value != 'none' &&
        value != 'false' &&
        value != '0';
  }

  DocxParagraphAlignment? _parseAlignment(String? value) {
    return switch (value) {
      'left' || 'start' => DocxParagraphAlignment.left,
      'center' => DocxParagraphAlignment.center,
      'right' || 'end' => DocxParagraphAlignment.right,
      'both' || 'distribute' => DocxParagraphAlignment.justify,
      _ => null,
    };
  }

  DocxVerticalAlignment? _parseVerticalAlignment(String? value) {
    return switch (value) {
      'superscript' => DocxVerticalAlignment.superscript,
      'subscript' => DocxVerticalAlignment.subscript,
      _ => null,
    };
  }

  String _parseSymbol(XmlElement element) {
    final font = _attribute(element, 'font') ?? '';
    final charCode = int.tryParse(_attribute(element, 'char') ?? '', radix: 16);
    if (charCode == null) {
      return '';
    }

    // Try the font-specific symbol map or fall back to the Unicode character.
    final fontMap = _symbolFontMap[font];
    if (fontMap != null && fontMap.containsKey(charCode)) {
      return fontMap[charCode]!;
    }

    // For characters in the Private Use Area, try to map via common fonts.
    if (charCode >= 0xF000 && charCode <= 0xF0FF) {
      final mapped = charCode - 0xF000;
      final fallbackMap = _symbolFontMap['Symbol'];
      if (fallbackMap != null && fallbackMap.containsKey(mapped)) {
        return fallbackMap[mapped]!;
      }
    }

    return String.fromCharCode(charCode);
  }

  double? _emuToPixels(String? value) {
    final emu = int.tryParse(value ?? '');
    return emu == null ? null : emu / _emuPerLogicalPixel;
  }

  double? _twipsToPixels(String? value) {
    final twips = int.tryParse(value ?? '');
    return twips == null ? null : twips / 15;
  }

  double? _lineHeight(String? value) {
    final line = int.tryParse(value ?? '');
    return line == null || line <= 0 ? null : line / 240;
  }

  double? _halfPoints(String? value) {
    final halfPoints = int.tryParse(value ?? '');
    return halfPoints == null ? null : halfPoints / 2;
  }

  int? _hexColor(String? value) {
    if (value == null || value.toLowerCase() == 'auto') {
      return null;
    }

    final parsed = int.tryParse(value, radix: 16);

    if (parsed == null) {
      return null;
    }

    return value.length <= 6 ? 0xFF000000 | parsed : parsed;
  }

  int? _highlightColor(String? value) {
    return switch (value?.toLowerCase()) {
      'black' => 0xFF000000,
      'blue' => 0xFF0000FF,
      'cyan' => 0xFF00FFFF,
      'green' => 0xFF00FF00,
      'magenta' => 0xFFFF00FF,
      'red' => 0xFFFF0000,
      'yellow' => 0xFFFFFF00,
      'white' => 0xFFFFFFFF,
      'darkblue' => 0xFF000080,
      'darkcyan' => 0xFF008080,
      'darkgreen' => 0xFF008000,
      'darkmagenta' => 0xFF800080,
      'darkred' => 0xFF800000,
      'darkyellow' => 0xFF808000,
      'darkgray' => 0xFF808080,
      'lightgray' => 0xFFC0C0C0,
      _ => null,
    };
  }

  DocxBuiltinKind _parseBuiltinKind(String? styleId) {
    if (styleId == null) {
      return DocxBuiltinKind.none;
    }

    return switch (styleId.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      'title' => DocxBuiltinKind.title,
      'subtitle' => DocxBuiltinKind.subtitle,
      'heading1' => DocxBuiltinKind.heading1,
      'heading2' => DocxBuiltinKind.heading2,
      'heading3' => DocxBuiltinKind.heading3,
      'normal' => DocxBuiltinKind.normal,
      _ => DocxBuiltinKind.none,
    };
  }

  // -----------------------------------------------------------------------
  // Styles.xml parsing
  // -----------------------------------------------------------------------

  _DocxStyles _parseStyles(String? xmlText) {
    final paragraphStyleMap = <String, _DocxParagraphStyleDef>{};
    final characterStyleMap = <String, _DocxCharacterStyleDef>{};

    if (xmlText == null) {
      return _DocxStyles(paragraphStyleMap, characterStyleMap);
    }

    final document = XmlDocument.parse(xmlText);

    for (final styleElement
        in document.descendants.whereType<XmlElement>()) {
      if (styleElement.name.local != 'style') {
        continue;
      }

      final type = _attribute(styleElement, 'type');
      final styleId = _attribute(styleElement, 'styleId');
      if (styleId == null) {
        continue;
      }

      if (type == 'paragraph') {
        final pPr = _directChild(styleElement, 'pPr');
        final rPr = _directChild(styleElement, 'rPr');
        paragraphStyleMap[styleId] = _DocxParagraphStyleDef(
          styleId: styleId,
          basedOn: _attribute(_directChild(styleElement, 'basedOn'), 'val'),
          rPr: rPr,
        );
      } else if (type == 'character') {
        final rPr = _directChild(styleElement, 'rPr');
        if (rPr != null) {
          characterStyleMap[styleId] = _DocxCharacterStyleDef(
            styleId: styleId,
            basedOn:
                _attribute(_directChild(styleElement, 'basedOn'), 'val'),
            bold: _isEnabled(rPr, 'b'),
            italic: _isEnabled(rPr, 'i'),
            underline: _isUnderline(rPr),
            strike: _isEnabled(rPr, 'strike'),
            allCaps: _isEnabled(rPr, 'caps'),
            smallCaps: _isEnabled(rPr, 'smallCaps'),
            fontSize: _halfPoints(
              _attribute(_directChild(rPr, 'sz'), 'val'),
            ),
            color: _hexColor(
              _attribute(_directChild(rPr, 'color'), 'val'),
            ),
            highlightColor: _highlightColor(
              _attribute(_directChild(rPr, 'highlight'), 'val'),
            ),
            fontFamily:
                _attribute(_directChild(rPr, 'rFonts'), 'ascii'),
          );
        }
      }
    }

    return _DocxStyles(paragraphStyleMap, characterStyleMap);
  }

  String _resolveWordPath(String target) {
    final normalized = target.replaceAll('\\', '/');

    if (normalized.startsWith('/')) {
      return normalized.substring(1);
    }

    return Uri.parse('word/document.xml').resolve(normalized).path;
  }

  // -----------------------------------------------------------------------
  // Relationships / Content-Types
  // -----------------------------------------------------------------------

  Map<String, _Relationship> _parseRelationships(String? xmlText) {
    if (xmlText == null) {
      return {};
    }

    final relationships = <String, _Relationship>{};

    for (final element in XmlDocument.parse(
      xmlText,
    ).descendants.whereType<XmlElement>()) {
      if (element.name.local != 'Relationship') {
        continue;
      }

      final id = _attribute(element, 'Id');
      final target = _attribute(element, 'Target');

      if (id != null && target != null) {
        relationships[id] = _Relationship(
          target: target,
          external: _attribute(element, 'TargetMode') == 'External',
        );
      }
    }

    return relationships;
  }

  _ContentTypes _parseContentTypes(String? xmlText) {
    final defaults = <String, String>{};
    final overrides = <String, String>{};

    if (xmlText == null) {
      return _ContentTypes(defaults, overrides);
    }

    for (final element in XmlDocument.parse(
      xmlText,
    ).descendants.whereType<XmlElement>()) {
      final contentType = _attribute(element, 'ContentType');

      if (element.name.local == 'Default' && contentType != null) {
        final extension = _attribute(element, 'Extension')?.toLowerCase();

        if (extension != null) {
          defaults[extension] = contentType;
        }
      } else if (element.name.local == 'Override' && contentType != null) {
        final partName = _attribute(element, 'PartName');

        if (partName != null) {
          overrides[partName] = contentType;
        }
      }
    }

    return _ContentTypes(defaults, overrides);
  }

  Map<int, Map<int, _NumberingLevel>> _parseNumbering(String? xmlText) {
    if (xmlText == null) {
      return {};
    }

    final document = XmlDocument.parse(xmlText);
    final abstracts = <int, Map<int, _NumberingLevel>>{};

    for (final abstract in document.descendants.whereType<XmlElement>()) {
      if (abstract.name.local != 'abstractNum') {
        continue;
      }

      final id = int.tryParse(_attribute(abstract, 'abstractNumId') ?? '');

      if (id == null) {
        continue;
      }

      final levels = <int, _NumberingLevel>{};

      for (final levelElement in abstract.childElements.where(
        (element) => element.name.local == 'lvl',
      )) {
        final level =
            int.tryParse(_attribute(levelElement, 'ilvl') ?? '') ?? 0;
        final format =
            _attribute(_directChild(levelElement, 'numFmt'), 'val');
        final start =
            int.tryParse(
              _attribute(_directChild(levelElement, 'start'), 'val') ?? '',
            ) ??
            1;
        levels[level] = _NumberingLevel(
          type: format == 'decimal'
              ? DocxListType.numbered
              : DocxListType.bullet,
          start: start,
        );
      }

      abstracts[id] = levels;
    }

    final numbering = <int, Map<int, _NumberingLevel>>{};

    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'num') {
        continue;
      }

      final numberId = int.tryParse(_attribute(element, 'numId') ?? '');
      final abstractId = int.tryParse(
        _attribute(_directChild(element, 'abstractNumId'), 'val') ?? '',
      );

      if (numberId != null && abstractId != null) {
        numbering[numberId] = abstracts[abstractId] ?? {};
      }
    }

    return numbering;
  }
}

// =========================================================================
// Internal state & helpers
// =========================================================================

class _ParseState {
  final Archive archive;
  final Map<String, _Relationship> relationships;
  final _ContentTypes contentTypes;
  final Map<int, Map<int, _NumberingLevel>> numbering;
  final Map<int, Map<int, int>> numberingCounters;
  final _DocxStyles styles;

  _ParseState({
    required this.archive,
    required this.relationships,
    required this.contentTypes,
    required this.numbering,
    required this.numberingCounters,
    required this.styles,
  });
}

class _Relationship {
  final String target;
  final bool external;

  const _Relationship({required this.target, required this.external});
}

class _ContentTypes {
  final Map<String, String> defaults;
  final Map<String, String> overrides;

  const _ContentTypes(this.defaults, this.overrides);

  String typeFor(String path) {
    final override = overrides['/$path'];

    if (override != null) {
      return override;
    }

    final dot = path.lastIndexOf('.');
    final extension = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return defaults[extension] ??
        switch (extension) {
          'png' => 'image/png',
          'jpg' || 'jpeg' => 'image/jpeg',
          'gif' => 'image/gif',
          'bmp' => 'image/bmp',
          'svg' => 'image/svg+xml',
          'tiff' || 'tif' => 'image/tiff',
          _ => 'application/octet-stream',
        };
  }
}

class _NumberingLevel {
  final DocxListType type;
  final int start;

  const _NumberingLevel({required this.type, required this.start});
}

// =========================================================================
// Styles.xml model
// =========================================================================

class _DocxStyles {
  final Map<String, _DocxParagraphStyleDef> paragraphStyles;
  final Map<String, _DocxCharacterStyleDef> characterStyles;

  const _DocxStyles(this.paragraphStyles, this.characterStyles);

  _DocxParagraphStyleDef? resolveParagraphStyle(String? styleId) {
    if (styleId == null) {
      return null;
    }
    return paragraphStyles[styleId];
  }

  _DocxCharacterStyleDef? findCharacterStyle(String? styleId) {
    if (styleId == null) {
      return null;
    }
    return characterStyles[styleId];
  }
}

class _DocxParagraphStyleDef {
  final String styleId;
  final String? basedOn;
  final XmlElement? rPr;

  const _DocxParagraphStyleDef({
    required this.styleId,
    this.basedOn,
    this.rPr,
  });
}

class _DocxCharacterStyleDef {
  final String styleId;
  final String? basedOn;
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

  const _DocxCharacterStyleDef({
    required this.styleId,
    this.basedOn,
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
  });
}

// =========================================================================
// Table row builder helpers (for vMerge resolution)
// =========================================================================

enum _VMerge { restart, continue_ }

class _CellBuilder {
  final List<DocxBlock> blocks;
  final int columnSpan;
  final double? width;
  int _rowSpan = 1;

  _CellBuilder({
    required this.blocks,
    this.columnSpan = 1,
    this.width,
  });
}

class _ParsedRow {
  final List<_CellBuilder> cells;
  final bool isHeader;

  const _ParsedRow({required this.cells, this.isHeader = false});
}
