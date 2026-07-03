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
      final parts = _findPartPaths(archive);
      final documentXml = _readArchiveText(archive, parts.document);

      if (documentXml == null) {
        throw const InvalidDocxException();
      }

      final document = XmlDocument.parse(documentXml);
      final body = _firstDescendant(document, 'body');

      if (body == null) {
        throw const InvalidDocxException();
      }

      final relationships = _parseRelationships(
        _readArchiveText(archive, _relationshipsPath(parts.document)),
      );
      final contentTypes = _parseContentTypes(
        _readArchiveText(archive, '[Content_Types].xml'),
      );
      final styles = _parseStyles(_readArchiveText(archive, parts.styles));
      final numbering = _parseNumbering(
        _readArchiveText(archive, parts.numbering),
        styles,
      );
      final state = _ParseState(
        archive: archive,
        partPath: parts.document,
        relationships: relationships,
        contentTypes: contentTypes,
        numbering: numbering,
        styles: styles,
        numberingCounters: <int, Map<int, int>>{},
      );

      return DocxDocument(
        blocks: _parseBlocks(body, state),
        notes: [
          ..._parseNotes(parts.footnotes, DocxNoteType.footnote, state),
          ..._parseNotes(parts.endnotes, DocxNoteType.endnote, state),
        ],
        comments: _parseComments(parts.comments, state),
      );
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
    return _parseBlockElements(parent.childElements, state);
  }

  List<DocxBlock> _parseBlockElements(
    Iterable<XmlElement> elements,
    _ParseState state,
  ) {
    final blocks = <DocxBlock>[];
    final deletedParagraphRuns = <DocxTextRun>[];
    final deletedParagraphBlocks = <DocxBlock>[];

    for (final child in elements) {
      switch (child.name.local) {
        case 'p':
          final parsed = _parseParagraph(child, state);
          final paragraphProperties = _directChild(child, 'pPr');
          final deleted =
              _directChild(_directChild(paragraphProperties, 'rPr'), 'del') !=
              null;
          if (deleted) {
            for (final block in parsed) {
              if (block is DocxParagraph) {
                deletedParagraphRuns.addAll(block.runs);
              } else {
                deletedParagraphBlocks.add(block);
              }
            }
            break;
          }
          if (deletedParagraphRuns.isNotEmpty &&
              parsed.isNotEmpty &&
              parsed.first is DocxParagraph) {
            final first = parsed.first as DocxParagraph;
            parsed[0] = DocxParagraph(
              runs: [...deletedParagraphRuns, ...first.runs],
              style: first.style,
              list: first.list,
            );
            deletedParagraphRuns.clear();
          }
          blocks.addAll(deletedParagraphBlocks);
          deletedParagraphBlocks.clear();
          blocks.addAll(parsed);
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
    final kind = _parseBuiltinKind(
      resolvedStyle?.name ?? resolvedStyle?.styleId ?? styleId,
    );

    final justification = paragraphProperties == null
        ? null
        : _directChild(paragraphProperties, 'jc');
    final spacing = paragraphProperties == null
        ? null
        : _directChild(paragraphProperties, 'spacing');
    final indent = paragraphProperties == null
        ? null
        : _directChild(paragraphProperties, 'ind');
    final inheritedSpacing = state.styles.findParagraphProperty(
      styleId,
      'spacing',
    );
    final inheritedIndent = state.styles.findParagraphProperty(styleId, 'ind');
    final alignment = _parseAlignment(_attribute(justification, 'val'));
    final spacingBefore = _twipsToPixels(
      _attribute(spacing, 'before') ?? _attribute(inheritedSpacing, 'before'),
    );
    final spacingAfter = _twipsToPixels(
      _attribute(spacing, 'after') ?? _attribute(inheritedSpacing, 'after'),
    );
    final line =
        _attribute(spacing, 'line') ?? _attribute(inheritedSpacing, 'line');
    final lineRule =
        _attribute(spacing, 'lineRule') ??
        _attribute(inheritedSpacing, 'lineRule');
    final lineHeight = lineRule == null || lineRule == 'auto'
        ? _lineHeight(line)
        : null;
    final lineSpacing = lineRule == 'exact' || lineRule == 'atLeast'
        ? _twipsToPixels(line)
        : null;

    final paragraphStyle = DocxParagraphStyle(
      styleId: resolvedStyle?.styleId ?? styleId,
      styleName: resolvedStyle?.name,
      kind: kind,
      align:
          alignment ??
          _parseAlignment(
            _attribute(
              state.styles.findParagraphProperty(styleId, 'jc'),
              'val',
            ),
          ),
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
      lineHeight: lineHeight,
      lineSpacing: lineSpacing,
      lineSpacingAtLeast: lineRule == 'atLeast',
      indentStart: _twipsToPixels(
        _attribute(indent, 'start') ??
            _attribute(indent, 'left') ??
            _attribute(inheritedIndent, 'start') ??
            _attribute(inheritedIndent, 'left'),
      ),
      indentEnd: _twipsToPixels(
        _attribute(indent, 'end') ??
            _attribute(indent, 'right') ??
            _attribute(inheritedIndent, 'end') ??
            _attribute(inheritedIndent, 'right'),
      ),
      firstLineIndent: _twipsToPixels(
        _attribute(indent, 'firstLine') ??
            _attribute(inheritedIndent, 'firstLine'),
      ),
      hangingIndent: _twipsToPixels(
        _attribute(indent, 'hanging') ?? _attribute(inheritedIndent, 'hanging'),
      ),
    );

    var list = _parseList(
      paragraphProperties,
      state,
      styleId: resolvedStyle?.styleId ?? styleId,
      inheritedNumberingProperties: state.styles.findParagraphProperty(
        styleId,
        'numPr',
      ),
    );
    final blocks = <DocxBlock>[];
    final extraBlocks = <DocxBlock>[];
    final runs = <DocxTextRun>[];
    final fields = _ComplexFieldState();

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
            paragraphStyleId: styleId,
            fields: fields,
            extraBlocks: extraBlocks,
          );
          break;
        case 'hyperlink':
          _parseHyperlink(child, state, runs, paragraphStyleId: styleId);
          break;
        case 'bookmarkStart':
          final name = _attribute(child, 'name');
          if (name != null && name != '_GoBack') {
            runs.add(DocxTextRun(text: '', anchor: name));
          }
          break;
        case 'pPr':
          // Already handled above
          break;
        case 'rPr':
          // Paragraph-level run properties (e.g., w:del) — ignored
          break;
        case 'del':
          break;
        case 'sdt':
          final checkbox = child.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 'checkbox')
              .firstOrNull;
          if (checkbox != null) {
            final checked = _onOff(checkbox, 'checked') ?? false;
            final content =
                _firstDescendant(child, 'sdtContent')?.innerText ?? '';
            runs.add(
              DocxTextRun(
                text:
                    '${checked ? '☑' : '☐'}${content.isEmpty ? '' : content.substring(1)}',
              ),
            );
            break;
          }
          for (final inner in _wordRuns(child)) {
            _parseRun(
              inner,
              state,
              runs,
              blocks,
              addParagraph,
              addBlock,
              list != null && runs.isEmpty && blocks.isEmpty,
              paragraphStyleId: styleId,
              fields: fields,
              extraBlocks: extraBlocks,
            );
          }
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
              paragraphStyleId: styleId,
              fields: fields,
              extraBlocks: extraBlocks,
            );
          }
          break;
      }
    }

    addParagraph(evenWhenEmpty: blocks.isEmpty);
    blocks.addAll(extraBlocks);
    return blocks;
  }

  void _parseRun(
    XmlElement run,
    _ParseState state,
    List<DocxTextRun> runs,
    List<DocxBlock> blocks,
    void Function({bool evenWhenEmpty}) addParagraph,
    void Function(DocxBlock) addBlock,
    bool hasList, {
    String? paragraphStyleId,
    _ComplexFieldState? fields,
    List<DocxBlock>? extraBlocks,
  }) {
    final properties = _directChild(run, 'rPr');
    final textStyle = _readRunStyle(
      properties,
      state.styles,
      paragraphStyleId: paragraphStyleId,
    );
    final styleId = properties == null
        ? null
        : _attribute(_directChild(properties, 'rStyle'), 'val');
    final characterStyle = state.styles.findCharacterStyle(styleId);
    final text = StringBuffer();

    void addTextRun() {
      if (text.isEmpty) {
        return;
      }

      runs.add(
        DocxTextRun(
          text: text.toString(),
          style: textStyle,
          styleId: styleId,
          styleName: characterStyle?.name,
          href: fields?.href,
          anchor: fields?.anchor,
        ),
      );
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
        case 'fldChar':
          addTextRun();
          final marker = fields?.handleFieldCharacter(child);
          if (marker != null) {
            runs.add(DocxTextRun(text: marker));
          }
        case 'instrText':
          fields?.addInstruction(child.innerText);
        case 'footnoteReference':
          addTextRun();
          final id = _attribute(child, 'id') ?? '';
          runs.add(
            DocxTextRun(
              text: '[${state.nextNoteNumber(DocxNoteType.footnote, id)}]',
              style: const DocxTextStyle(
                verticalAlignment: DocxVerticalAlignment.superscript,
              ),
              anchor: 'footnote-$id',
            ),
          );
        case 'endnoteReference':
          addTextRun();
          final id = _attribute(child, 'id') ?? '';
          runs.add(
            DocxTextRun(
              text: '[${state.nextNoteNumber(DocxNoteType.endnote, id)}]',
              style: const DocxTextStyle(
                verticalAlignment: DocxVerticalAlignment.superscript,
              ),
              anchor: 'endnote-$id',
            ),
          );
        case 'commentReference':
          addTextRun();
          final id = _attribute(child, 'id') ?? '';
          runs.add(
            DocxTextRun(
              text: '[${state.nextCommentNumber(id)}]',
              style: const DocxTextStyle(
                verticalAlignment: DocxVerticalAlignment.superscript,
              ),
              anchor: 'comment-$id',
            ),
          );
        case 'drawing' || 'pict':
          addTextRun();
          final images = _parseImages(child, state);
          if (images.isNotEmpty) {
            // Only emit an empty paragraph when there is a pending list, so
            // that list numbering resumes after the image.
            if (hasList) {
              addParagraph(evenWhenEmpty: true);
            } else {
              addParagraph();
            }
            blocks.addAll(images);
          }
          for (final textBox in child.descendants.whereType<XmlElement>().where(
            (element) => element.name.local == 'txbxContent',
          )) {
            (extraBlocks ?? blocks).addAll(_parseBlocks(textBox, state));
          }
      }
    }

    addTextRun();
  }

  void _parseHyperlink(
    XmlElement element,
    _ParseState state,
    List<DocxTextRun> runs, {
    String? paragraphStyleId,
  }) {
    final relationshipId = _attribute(element, 'id');
    final anchor = _attribute(element, 'anchor');
    String? href;

    final relationship = state.relationships[relationshipId];
    if (relationship != null) {
      href = relationship.target;
      if (anchor != null) {
        href = Uri.parse(href).replace(fragment: anchor).toString();
      }
    }

    for (final child in element.childElements) {
      if (child.name.local == 'r') {
        final properties = _directChild(child, 'rPr');
        final textStyle = _readRunStyle(
          properties,
          state.styles,
          paragraphStyleId: paragraphStyleId,
        );
        final styleId = properties == null
            ? null
            : _attribute(_directChild(properties, 'rStyle'), 'val');
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
          runs.add(
            DocxTextRun(
              text: text.toString(),
              style: textStyle,
              styleId: styleId,
              styleName: state.styles.findCharacterStyle(styleId)?.name,
              href: href,
              anchor: href == null ? anchor : null,
            ),
          );
        }
      }
    }
  }

  DocxTextStyle _readRunStyle(
    XmlElement? properties,
    _DocxStyles styles, {
    String? paragraphStyleId,
  }) {
    final styleId = properties == null
        ? null
        : _attribute(_directChild(properties, 'rStyle'), 'val');
    XmlElement? inherited(String name) =>
        styles.findRunProperty(styleId, paragraphStyleId, name);

    return DocxTextStyle(
      bold: _onOff(properties, 'b') ?? _onOffElement(inherited('b')) ?? false,
      italic: _onOff(properties, 'i') ?? _onOffElement(inherited('i')) ?? false,
      underline:
          _underline(properties) ?? _underlineElement(inherited('u')) ?? false,
      strike:
          _onOff(properties, 'strike') ??
          _onOffElement(inherited('strike')) ??
          false,
      allCaps:
          _onOff(properties, 'caps') ??
          _onOffElement(inherited('caps')) ??
          false,
      smallCaps:
          _onOff(properties, 'smallCaps') ??
          _onOffElement(inherited('smallCaps')) ??
          false,
      fontSize:
          _halfPointsToPixels(
            _attribute(
              _directChild(properties, 'sz') ??
                  _directChild(properties, 'szCs'),
              'val',
            ),
          ) ??
          _halfPointsToPixels(
            _attribute(inherited('sz') ?? inherited('szCs'), 'val'),
          ),
      color:
          _hexColor(_attribute(_directChild(properties, 'color'), 'val')) ??
          _hexColor(_attribute(inherited('color'), 'val')),
      highlightColor:
          _highlightColor(
            _attribute(_directChild(properties, 'highlight'), 'val'),
          ) ??
          _highlightColor(_attribute(inherited('highlight'), 'val')),
      fontFamily:
          _fontFamily(_directChild(properties, 'rFonts')) ??
          _fontFamily(inherited('rFonts')),
      verticalAlignment:
          _parseVerticalAlignment(
            _attribute(_directChild(properties, 'vertAlign'), 'val'),
          ) ??
          _parseVerticalAlignment(_attribute(inherited('vertAlign'), 'val')),
    );
  }

  // -----------------------------------------------------------------------
  // Image parsing
  // -----------------------------------------------------------------------

  List<DocxImage> _parseImages(XmlElement drawing, _ParseState state) {
    final extent = _firstDescendant(drawing, 'extent');
    final width = _emuToPixels(_attribute(extent, 'cx'));
    final height = _emuToPixels(_attribute(extent, 'cy'));
    final properties = drawing.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'docPr')
        .firstOrNull;
    final altText =
        _blankToNull(_attribute(properties, 'descr')) ??
        _blankToNull(_attribute(properties, 'title'));
    final imageLinkId = properties?.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'hlinkClick')
        .map((element) => _attribute(element, 'id'))
        .firstOrNull;
    final href = state.relationships[imageLinkId]?.target;
    final images = <DocxImage>[];

    for (final element in drawing.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'blip' && element.name.local != 'imagedata') {
        continue;
      }

      final relationshipId =
          _attribute(element, 'embed') ??
          _attribute(element, 'link') ??
          _attribute(element, 'id');
      final relationship = state.relationships[relationshipId];
      final path = relationship == null || relationship.external
          ? null
          : _resolvePartPath(state.partPath, relationship.target);
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
          altText: altText ?? _blankToNull(_attribute(element, 'title')),
          href: href,
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
    _ParseState state, {
    String? styleId,
    XmlElement? inheritedNumberingProperties,
  }) {
    final numberingProperties =
        _directChild(paragraphProperties, 'numPr') ??
        inheritedNumberingProperties;

    final level =
        int.tryParse(
          _attribute(_directChild(numberingProperties, 'ilvl'), 'val') ?? '',
        ) ??
        0;
    var numberId = int.tryParse(
      _attribute(_directChild(numberingProperties, 'numId'), 'val') ?? '',
    );
    if (numberId == 0) {
      return null;
    }
    var definition = numberId == null
        ? null
        : state.numbering[numberId]?[level];
    if (definition == null && styleId != null) {
      for (final entry in state.numbering.entries) {
        for (final candidate in entry.value.values) {
          if (candidate.paragraphStyleId == styleId) {
            numberId = entry.key;
            definition = candidate;
            break;
          }
        }
        if (definition != null) {
          break;
        }
      }
    }
    if (definition == null) {
      return null;
    }
    final type = definition.type;
    final indentStart = definition.indentStart;
    final hangingIndent = definition.hangingIndent;

    if (type == DocxListType.bullet || numberId == null) {
      return DocxListInfo(
        type: type,
        level: level,
        indentStart: indentStart,
        hangingIndent: hangingIndent,
      );
    }

    final counters = state.numberingCounters.putIfAbsent(
      numberId,
      () => <int, int>{},
    );
    counters.removeWhere((counterLevel, _) => counterLevel > level);
    final number = (counters[level] ?? definition.start - 1) + 1;
    counters[level] = number;

    return DocxListInfo(
      type: type,
      level: level,
      number: number,
      marker: _numberingMarker(state.numbering[numberId]!, counters, level),
      indentStart: indentStart,
      hangingIndent: hangingIndent,
    );
  }

  String _numberingMarker(
    Map<int, _NumberingLevel> definitions,
    Map<int, int> counters,
    int level,
  ) {
    var marker = definitions[level]?.text ?? '%${level + 1}.';
    for (var index = 0; index <= level; index++) {
      final value = counters[index];
      if (value == null) {
        continue;
      }
      marker = marker.replaceAll(
        '%${index + 1}',
        _formatNumber(value, definitions[index]?.format),
      );
    }
    return marker;
  }

  String _formatNumber(int value, String? format) {
    if (format == 'chineseCounting') {
      return _chineseCounting(value);
    }
    return value.toString();
  }

  String _chineseCounting(int value) {
    if (value <= 0 || value > 9999) {
      return value.toString();
    }
    const digits = '零一二三四五六七八九';
    const units = ['', '十', '百', '千'];
    const divisors = [1, 10, 100, 1000];
    final output = StringBuffer();
    var needsZero = false;
    for (var power = 3; power >= 0; power--) {
      final digit = value ~/ divisors[power] % 10;
      if (digit == 0) {
        needsZero = output.isNotEmpty && value % divisors[power] != 0;
        continue;
      }
      if (needsZero) {
        output.write('零');
        needsZero = false;
      }
      if (!(digit == 1 && power == 1 && output.isEmpty)) {
        output.write(digits[digit]);
      }
      output.write(units[power]);
    }
    return output.toString();
  }

  // -----------------------------------------------------------------------
  // Table parsing
  // -----------------------------------------------------------------------

  DocxTable _parseTable(XmlElement table, _ParseState state) {
    final tableProperties = _directChild(table, 'tblPr');
    final styleId = _attribute(
      _directChild(tableProperties, 'tblStyle'),
      'val',
    );
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
      if (_directChild(rowProperties, 'del') != null) {
        continue;
      }
      final isHeader =
          rowProperties != null &&
          _directChild(rowProperties, 'tblHeader') != null;
      final cells = <_CellBuilder>[];
      var columnCursor = 0;
      final continuedColumns = <int>{};

      for (final cell in row.childElements.where((e) => e.name.local == 'tc')) {
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
          if (activeCell != null &&
              activeCell.columnSpan == cellBuilder.columnSpan) {
            activeCell._rowSpan++;
            for (
              var c = columnCursor;
              c < columnCursor + cellBuilder.columnSpan;
              c++
            ) {
              continuedColumns.add(c);
            }
          }
        } else if (vMerge == _VMerge.restart) {
          // Start a new vertical merge group.
          for (
            var c = columnCursor;
            c < columnCursor + cellBuilder.columnSpan;
            c++
          ) {
            activeVMerges[c] = cellBuilder;
            continuedColumns.add(c);
          }
          cells.add(cellBuilder);
        } else {
          // No vertical merge – clear any stale tracking in this range.
          for (
            var c = columnCursor;
            c < columnCursor + cellBuilder.columnSpan;
            c++
          ) {
            activeVMerges.remove(c);
          }
          cells.add(cellBuilder);
        }

        columnCursor += cellBuilder.columnSpan;
      }

      activeVMerges.removeWhere(
        (column, _) => !continuedColumns.contains(column),
      );

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
      styleId: styleId,
      styleName: state.styles.tableStyles[styleId],
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
    if (val == null || val == 'continue') {
      return _VMerge.continue_;
    }
    return _VMerge.restart;
  }

  // -----------------------------------------------------------------------
  // Style resolution helpers
  // -----------------------------------------------------------------------

  Iterable<XmlElement> _wordRuns(XmlElement paragraph) sync* {
    if (paragraph.name.local == 'AlternateContent') {
      final fallback = _directChild(paragraph, 'Fallback');
      if (fallback != null) {
        yield* _wordRuns(fallback);
      }
      return;
    }
    for (final child in paragraph.childElements) {
      if (child.name.local == 'r') {
        yield child;
      } else if (child.name.local == 'del') {
        continue;
      } else if (child.name.local == 'AlternateContent') {
        final fallback = _directChild(child, 'Fallback');
        if (fallback != null) {
          yield* _wordRuns(fallback);
        }
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

  _PartPaths _findPartPaths(Archive archive) {
    final packageRelationships = _parseRelationships(
      _readArchiveText(archive, '_rels/.rels'),
    );
    final relatedDocument = packageRelationships.values
        .where((relationship) => relationship.type.endsWith('/officeDocument'))
        .map((relationship) => _resolvePartPath('', relationship.target))
        .where((path) => _readArchiveBytes(archive, path) != null)
        .firstOrNull;
    final document = relatedDocument ?? 'word/document.xml';
    final relationships = _parseRelationships(
      _readArchiveText(archive, _relationshipsPath(document)),
    );

    String related(String name) {
      final target = relationships.values
          .where((relationship) => relationship.type.endsWith('/$name'))
          .map(
            (relationship) => _resolvePartPath(document, relationship.target),
          )
          .where((path) => _readArchiveBytes(archive, path) != null)
          .firstOrNull;
      final slash = document.lastIndexOf('/');
      final directory = slash < 0 ? '' : document.substring(0, slash + 1);
      return target ?? '$directory$name.xml';
    }

    return _PartPaths(
      document: document,
      styles: related('styles'),
      numbering: related('numbering'),
      footnotes: related('footnotes'),
      endnotes: related('endnotes'),
      comments: related('comments'),
    );
  }

  String _relationshipsPath(String partPath) {
    final slash = partPath.lastIndexOf('/');
    final directory = slash < 0 ? '' : partPath.substring(0, slash + 1);
    final filename = slash < 0 ? partPath : partPath.substring(slash + 1);
    return '${directory}_rels/$filename.rels';
  }

  String _resolvePartPath(String sourcePart, String target) {
    final normalized = target.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      return normalized.substring(1);
    }
    final base = sourcePart.isEmpty
        ? Uri(path: '/')
        : Uri(path: '/$sourcePart');
    return base.resolve(normalized).path.substring(1);
  }

  List<DocxNote> _parseNotes(
    String path,
    DocxNoteType type,
    _ParseState parentState,
  ) {
    final xml = _readArchiveText(parentState.archive, path);
    if (xml == null) {
      return const [];
    }
    final state = parentState.forPart(
      path,
      _parseRelationships(
        _readArchiveText(parentState.archive, _relationshipsPath(path)),
      ),
    );
    final elementName = type == DocxNoteType.footnote ? 'footnote' : 'endnote';

    return [
      for (final element
          in XmlDocument.parse(xml).descendants.whereType<XmlElement>().where(
            (element) => element.name.local == elementName,
          ))
        if (!{
          'separator',
          'continuationSeparator',
        }.contains(_attribute(element, 'type')))
          DocxNote(
            id: _attribute(element, 'id') ?? '',
            type: type,
            blocks: _parseBlocks(element, state),
          ),
    ];
  }

  List<DocxComment> _parseComments(String path, _ParseState parentState) {
    final xml = _readArchiveText(parentState.archive, path);
    if (xml == null) {
      return const [];
    }
    final state = parentState.forPart(
      path,
      _parseRelationships(
        _readArchiveText(parentState.archive, _relationshipsPath(path)),
      ),
    );

    return [
      for (final element
          in XmlDocument.parse(xml).descendants.whereType<XmlElement>().where(
            (element) => element.name.local == 'comment',
          ))
        DocxComment(
          id: _attribute(element, 'id') ?? '',
          authorName: _blankToNull(_attribute(element, 'author')),
          authorInitials: _blankToNull(_attribute(element, 'initials')),
          blocks: _parseBlocks(element, state),
        ),
    ];
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

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

  XmlElement? _directChild(XmlElement? parent, String localName) {
    if (parent == null) {
      return null;
    }
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

  bool? _onOff(XmlElement? properties, String localName) {
    return _onOffElement(_directChild(properties, localName));
  }

  bool? _onOffElement(XmlElement? property) {
    if (property == null) return null;
    final value = _attribute(property, 'val')?.toLowerCase();
    return value != '0' &&
        value != 'false' &&
        value != 'off' &&
        value != 'none';
  }

  bool? _underline(XmlElement? properties) {
    return _underlineElement(_directChild(properties, 'u'));
  }

  bool? _underlineElement(XmlElement? property) {
    if (property == null) return null;
    final value = _attribute(property, 'val')?.toLowerCase();
    return value != null && value != 'none' && value != 'false' && value != '0';
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

  double? _halfPointsToPixels(String? value) {
    final halfPoints = int.tryParse(value ?? '');
    return halfPoints == null || halfPoints <= 0 ? null : halfPoints * 2 / 3;
  }

  String? _fontFamily(XmlElement? fonts) {
    return _attribute(fonts, 'ascii') ??
        _attribute(fonts, 'hAnsi') ??
        _attribute(fonts, 'eastAsia') ??
        _attribute(fonts, 'cs');
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
    final tableStyleMap = <String, String?>{};
    final numberingStyleMap = <String, int?>{};

    if (xmlText == null) {
      return _DocxStyles(
        paragraphStyleMap,
        characterStyleMap,
        tableStyleMap,
        numberingStyleMap,
      );
    }

    final document = XmlDocument.parse(xmlText);
    final defaults = _firstDescendant(document, 'docDefaults');
    final defaultParagraphProperties = defaults == null
        ? null
        : _firstDescendant(defaults, 'pPr');
    final defaultRunProperties = defaults == null
        ? null
        : _firstDescendant(defaults, 'rPr');

    for (final styleElement in document.descendants.whereType<XmlElement>()) {
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
          name: _attribute(_directChild(styleElement, 'name'), 'val'),
          basedOn: _attribute(_directChild(styleElement, 'basedOn'), 'val'),
          pPr: pPr,
          rPr: rPr,
        );
      } else if (type == 'character') {
        final rPr = _directChild(styleElement, 'rPr');
        characterStyleMap[styleId] = _DocxCharacterStyleDef(
          styleId: styleId,
          name: _attribute(_directChild(styleElement, 'name'), 'val'),
          basedOn: _attribute(_directChild(styleElement, 'basedOn'), 'val'),
          rPr: rPr,
        );
      } else if (type == 'table') {
        tableStyleMap.putIfAbsent(
          styleId,
          () => _attribute(_directChild(styleElement, 'name'), 'val'),
        );
      } else if (type == 'numbering') {
        numberingStyleMap.putIfAbsent(
          styleId,
          () => int.tryParse(
            _attribute(
                  _directChild(
                    _directChild(_directChild(styleElement, 'pPr'), 'numPr'),
                    'numId',
                  ),
                  'val',
                ) ??
                '',
          ),
        );
      }
    }

    return _DocxStyles(
      paragraphStyleMap,
      characterStyleMap,
      tableStyleMap,
      numberingStyleMap,
      defaultParagraphProperties,
      defaultRunProperties,
    );
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
          type: _attribute(element, 'Type') ?? '',
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

  Map<int, Map<int, _NumberingLevel>> _parseNumbering(
    String? xmlText,
    _DocxStyles styles,
  ) {
    if (xmlText == null) {
      return {};
    }

    final document = XmlDocument.parse(xmlText);
    final abstracts = <int, Map<int, _NumberingLevel>>{};
    final abstractStyleLinks = <int, String>{};

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
        final level = int.tryParse(_attribute(levelElement, 'ilvl') ?? '') ?? 0;
        final format = _attribute(_directChild(levelElement, 'numFmt'), 'val');
        final start =
            int.tryParse(
              _attribute(_directChild(levelElement, 'start'), 'val') ?? '',
            ) ??
            1;
        final indent = _directChild(_directChild(levelElement, 'pPr'), 'ind');
        levels[level] = _NumberingLevel(
          type: format == 'bullet'
              ? DocxListType.bullet
              : DocxListType.numbered,
          format: format,
          text: _attribute(_directChild(levelElement, 'lvlText'), 'val'),
          start: start,
          paragraphStyleId: _attribute(
            _directChild(levelElement, 'pStyle'),
            'val',
          ),
          indentStart: _twipsToPixels(
            _attribute(indent, 'start') ?? _attribute(indent, 'left'),
          ),
          hangingIndent: _twipsToPixels(_attribute(indent, 'hanging')),
        );
      }

      abstracts[id] = levels;
      final styleLink = _attribute(
        _directChild(abstract, 'numStyleLink'),
        'val',
      );
      if (styleLink != null) {
        abstractStyleLinks[id] = styleLink;
      }
    }

    final numberToAbstract = <int, int>{};
    final numberElements = <int, XmlElement>{};

    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'num') {
        continue;
      }

      final numberId = int.tryParse(_attribute(element, 'numId') ?? '');
      final abstractId = int.tryParse(
        _attribute(_directChild(element, 'abstractNumId'), 'val') ?? '',
      );

      if (numberId != null && abstractId != null) {
        numberToAbstract[numberId] = abstractId;
        numberElements[numberId] = element;
      }
    }

    final numbering = <int, Map<int, _NumberingLevel>>{};

    Map<int, _NumberingLevel> resolve(int numberId, Set<int> visited) {
      if (!visited.add(numberId)) {
        return const {};
      }
      final abstractId = numberToAbstract[numberId];
      if (abstractId == null) {
        return const {};
      }
      final styleLink = abstractStyleLinks[abstractId];
      final linkedNumberId = styleLink == null
          ? null
          : styles.numberingStyles[styleLink];
      final resolved = Map<int, _NumberingLevel>.of(
        linkedNumberId == null
            ? abstracts[abstractId] ?? const {}
            : resolve(linkedNumberId, visited),
      );
      for (final override in numberElements[numberId]!.childElements.where(
        (element) => element.name.local == 'lvlOverride',
      )) {
        final level = int.tryParse(_attribute(override, 'ilvl') ?? '');
        if (level == null) {
          continue;
        }
        final start = int.tryParse(
          _attribute(_directChild(override, 'startOverride'), 'val') ?? '',
        );
        final current = resolved[level];
        if (start != null && current != null) {
          resolved[level] = current.withStart(start);
        }
      }
      return resolved;
    }

    for (final numberId in numberToAbstract.keys) {
      numbering[numberId] = resolve(numberId, <int>{});
    }

    return numbering;
  }
}

// =========================================================================
// Internal state & helpers
// =========================================================================

class _ParseState {
  final Archive archive;
  final String partPath;
  final Map<String, _Relationship> relationships;
  final _ContentTypes contentTypes;
  final Map<int, Map<int, _NumberingLevel>> numbering;
  final Map<int, Map<int, int>> numberingCounters;
  final _DocxStyles styles;
  final Map<String, int> noteNumbers;
  final Map<String, int> commentNumbers;

  _ParseState({
    required this.archive,
    required this.partPath,
    required this.relationships,
    required this.contentTypes,
    required this.numbering,
    required this.numberingCounters,
    required this.styles,
    Map<String, int>? noteNumbers,
    Map<String, int>? commentNumbers,
  }) : noteNumbers = noteNumbers ?? <String, int>{},
       commentNumbers = commentNumbers ?? <String, int>{};

  int nextNoteNumber(DocxNoteType type, String id) {
    final key = '${type.name}:$id';
    return noteNumbers.putIfAbsent(key, () => noteNumbers.length + 1);
  }

  int nextCommentNumber(String id) {
    return commentNumbers.putIfAbsent(id, () => commentNumbers.length + 1);
  }

  _ParseState forPart(
    String path,
    Map<String, _Relationship> partRelationships,
  ) {
    return _ParseState(
      archive: archive,
      partPath: path,
      relationships: partRelationships,
      contentTypes: contentTypes,
      numbering: numbering,
      numberingCounters: <int, Map<int, int>>{},
      styles: styles,
      noteNumbers: noteNumbers,
      commentNumbers: commentNumbers,
    );
  }
}

class _ComplexFieldState {
  final List<_ComplexField> _fields = [];

  String? get href => _activeHyperlink?.href;
  String? get anchor => _activeHyperlink?.anchor;

  _ComplexField? get _activeHyperlink {
    for (final field in _fields.reversed) {
      if (field.separated && (field.href != null || field.anchor != null)) {
        return field;
      }
    }
    return null;
  }

  void addInstruction(String value) {
    if (_fields.isNotEmpty) {
      _fields.last.instruction.write(value);
    }
  }

  String? handleFieldCharacter(XmlElement element) {
    switch (_attributeValue(element, 'fldCharType')) {
      case 'begin':
        final checkedElement = element.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'checked')
            .firstOrNull;
        final defaultElement = element.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'default')
            .firstOrNull;
        _fields.add(
          _ComplexField(
            checked:
                _booleanValue(checkedElement) ??
                _booleanValue(defaultElement) ??
                false,
          ),
        );
      case 'separate':
        if (_fields.isNotEmpty) {
          _fields.last.parse();
        }
      case 'end':
        if (_fields.isEmpty) {
          return null;
        }
        final field = _fields.removeLast();
        return field.isCheckbox ? (field.checked ? '☑' : '☐') : null;
    }
    return null;
  }

  static String? _attributeValue(XmlElement element, String name) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == name) {
        return attribute.value;
      }
    }
    return null;
  }

  static bool? _booleanValue(XmlElement? element) {
    if (element == null) {
      return null;
    }
    final value = _attributeValue(element, 'val')?.toLowerCase();
    return value == null || !{'0', 'false', 'off'}.contains(value);
  }
}

class _ComplexField {
  final StringBuffer instruction = StringBuffer();
  final bool checked;
  bool separated = false;
  bool isCheckbox = false;
  String? href;
  String? anchor;

  _ComplexField({required this.checked});

  void parse() {
    separated = true;
    final value = instruction.toString();
    isCheckbox = RegExp(
      r'\bFORMCHECKBOX\b',
      caseSensitive: false,
    ).hasMatch(value);
    final match = RegExp(
      r'''^\s*HYPERLINK\s+(\\l\s+)?(?:"([^"]*)"|([^\\\s]+))''',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) {
      return;
    }
    if (match.group(1) != null) {
      anchor = match.group(2) ?? match.group(3);
    } else {
      href = match.group(2) ?? match.group(3);
    }
  }
}

class _Relationship {
  final String target;
  final String type;
  final bool external;

  const _Relationship({
    required this.target,
    required this.type,
    required this.external,
  });
}

class _PartPaths {
  final String document;
  final String styles;
  final String numbering;
  final String footnotes;
  final String endnotes;
  final String comments;

  const _PartPaths({
    required this.document,
    required this.styles,
    required this.numbering,
    required this.footnotes,
    required this.endnotes,
    required this.comments,
  });
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
  final String? format;
  final String? text;
  final int start;
  final String? paragraphStyleId;
  final double? indentStart;
  final double? hangingIndent;

  const _NumberingLevel({
    required this.type,
    this.format,
    this.text,
    required this.start,
    this.paragraphStyleId,
    this.indentStart,
    this.hangingIndent,
  });

  _NumberingLevel withStart(int value) {
    return _NumberingLevel(
      type: type,
      format: format,
      text: text,
      start: value,
      paragraphStyleId: paragraphStyleId,
      indentStart: indentStart,
      hangingIndent: hangingIndent,
    );
  }
}

// =========================================================================
// Styles.xml model
// =========================================================================

class _DocxStyles {
  final Map<String, _DocxParagraphStyleDef> paragraphStyles;
  final Map<String, _DocxCharacterStyleDef> characterStyles;
  final Map<String, String?> tableStyles;
  final Map<String, int?> numberingStyles;
  final XmlElement? defaultParagraphProperties;
  final XmlElement? defaultRunProperties;

  const _DocxStyles(
    this.paragraphStyles,
    this.characterStyles,
    this.tableStyles,
    this.numberingStyles, [
    this.defaultParagraphProperties,
    this.defaultRunProperties,
  ]);

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

  XmlElement? findParagraphProperty(String? styleId, String name) {
    final visited = <String>{};
    var currentId = styleId;
    while (currentId != null && visited.add(currentId)) {
      final style = paragraphStyles[currentId];
      final property = _child(style?.pPr, name);
      if (property != null) {
        return property;
      }
      currentId = style?.basedOn;
    }
    return _child(defaultParagraphProperties, name);
  }

  XmlElement? findRunProperty(
    String? characterStyleId,
    String? paragraphStyleId,
    String name,
  ) {
    final visited = <String>{};
    var currentCharacterId = characterStyleId;
    while (currentCharacterId != null && visited.add(currentCharacterId)) {
      final style = characterStyles[currentCharacterId];
      final property = _child(style?.rPr, name);
      if (property != null) {
        return property;
      }
      currentCharacterId = style?.basedOn;
    }

    visited.clear();
    var currentParagraphId = paragraphStyleId;
    while (currentParagraphId != null && visited.add(currentParagraphId)) {
      final style = paragraphStyles[currentParagraphId];
      final property = _child(style?.rPr, name);
      if (property != null) {
        return property;
      }
      currentParagraphId = style?.basedOn;
    }
    return _child(defaultRunProperties, name);
  }

  static XmlElement? _child(XmlElement? parent, String name) {
    if (parent == null) {
      return null;
    }
    for (final child in parent.childElements) {
      if (child.name.local == name) {
        return child;
      }
    }
    return null;
  }
}

class _DocxParagraphStyleDef {
  final String styleId;
  final String? name;
  final String? basedOn;
  final XmlElement? pPr;
  final XmlElement? rPr;

  const _DocxParagraphStyleDef({
    required this.styleId,
    this.name,
    this.basedOn,
    this.pPr,
    this.rPr,
  });
}

class _DocxCharacterStyleDef {
  final String styleId;
  final String? name;
  final String? basedOn;
  final XmlElement? rPr;

  const _DocxCharacterStyleDef({
    required this.styleId,
    this.name,
    this.basedOn,
    this.rPr,
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

  _CellBuilder({required this.blocks, this.columnSpan = 1, this.width});
}

class _ParsedRow {
  final List<_CellBuilder> cells;
  final bool isHeader;

  const _ParsedRow({required this.cells, this.isHeader = false});
}
