import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/preview_exception.dart';
import '../models/docx_document.dart';

const _emuPerLogicalPixel = 9525;

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
      );

      return DocxDocument(blocks: _parseBlocks(body, state));
    } on PreviewException {
      rethrow;
    } catch (_) {
      throw const InvalidDocxException();
    }
  }

  List<DocxBlock> _parseBlocks(XmlElement parent, _ParseState state) {
    final blocks = <DocxBlock>[];

    for (final child in parent.childElements) {
      switch (child.name.local) {
        case 'p':
          blocks.addAll(_parseParagraph(child, state));
        case 'tbl':
          blocks.add(_parseTable(child, state));
      }
    }

    return blocks;
  }

  List<DocxBlock> _parseParagraph(XmlElement paragraph, _ParseState state) {
    final paragraphProperties = _directChild(paragraph, 'pPr');
    final styleId = _attribute(
      paragraphProperties == null
          ? null
          : _directChild(paragraphProperties, 'pStyle'),
      'val',
    );
    final justification = paragraphProperties == null
        ? null
        : _directChild(paragraphProperties, 'jc');
    final alignment = _parseAlignment(_attribute(justification, 'val'));
    var list = _parseList(paragraphProperties, state);
    final blocks = <DocxBlock>[];
    final runs = <DocxTextRun>[];

    void addParagraph({bool evenWhenEmpty = false}) {
      if (runs.isEmpty && !evenWhenEmpty) {
        return;
      }

      blocks.add(
        DocxParagraph(
          runs: List.of(runs),
          alignment: alignment,
          styleId: styleId,
          list: list,
        ),
      );
      runs.clear();
      list = null;
    }

    for (final run in _wordRuns(paragraph)) {
      final properties = _directChild(run, 'rPr');
      final bold = _isEnabled(properties, 'b');
      final italic = _isEnabled(properties, 'i');
      final underline = _isEnabled(properties, 'u');
      final text = StringBuffer();

      void addTextRun() {
        if (text.isEmpty) {
          return;
        }

        runs.add(
          DocxTextRun(
            text: text.toString(),
            bold: bold,
            italic: italic,
            underline: underline,
          ),
        );
        text.clear();
      }

      for (final child in run.childElements) {
        switch (child.name.local) {
          case 't':
            text.write(child.innerText);
          case 'br':
            text.write('\n');
          case 'tab':
            text.write('\t');
          case 'drawing':
            addTextRun();

            if (list != null && runs.isEmpty && blocks.isEmpty) {
              addParagraph(evenWhenEmpty: true);
            } else {
              addParagraph();
            }

            blocks.addAll(_parseImages(child, state));
        }
      }

      addTextRun();
    }

    addParagraph(evenWhenEmpty: blocks.isEmpty);
    return blocks;
  }

  Iterable<XmlElement> _wordRuns(XmlElement paragraph) sync* {
    for (final child in paragraph.childElements) {
      if (child.name.local == 'r') {
        yield child;
      } else if (child.name.local != 'pPr' && child.name.local != 'drawing') {
        yield* _wordRuns(child);
      }
    }
  }

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

  DocxListInfo? _parseList(XmlElement? paragraphProperties, _ParseState state) {
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

    final counters = state.numberingCounters.putIfAbsent(numberId, () => {});
    counters.removeWhere((counterLevel, _) => counterLevel > level);
    final number = (counters[level] ?? (definition?.start ?? 1) - 1) + 1;
    counters[level] = number;

    return DocxListInfo(type: type, level: level, number: number);
  }

  DocxTable _parseTable(XmlElement table, _ParseState state) {
    final rows = <DocxTableRow>[];

    for (final row in table.childElements.where((e) => e.name.local == 'tr')) {
      final cells = <DocxTableCell>[];

      for (final cell in row.childElements.where((e) => e.name.local == 'tc')) {
        cells.add(DocxTableCell(blocks: _parseBlocks(cell, state)));
      }

      rows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(rows: rows);
  }

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
        final level = int.tryParse(_attribute(levelElement, 'ilvl') ?? '') ?? 0;
        final format = _attribute(_directChild(levelElement, 'numFmt'), 'val');
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

  DocxParagraphAlignment? _parseAlignment(String? value) {
    return switch (value) {
      'left' || 'start' => DocxParagraphAlignment.left,
      'center' => DocxParagraphAlignment.center,
      'right' || 'end' => DocxParagraphAlignment.right,
      'both' || 'distribute' => DocxParagraphAlignment.justify,
      _ => null,
    };
  }

  String _resolveWordPath(String target) {
    final normalized = target.replaceAll('\\', '/');

    if (normalized.startsWith('/')) {
      return normalized.substring(1);
    }

    return Uri.parse('word/document.xml').resolve(normalized).path;
  }

  double? _emuToPixels(String? value) {
    final emu = int.tryParse(value ?? '');
    return emu == null ? null : emu / _emuPerLogicalPixel;
  }
}

class _ParseState {
  final Archive archive;
  final Map<String, _Relationship> relationships;
  final _ContentTypes contentTypes;
  final Map<int, Map<int, _NumberingLevel>> numbering;
  final Map<int, Map<int, int>> numberingCounters = {};

  _ParseState({
    required this.archive,
    required this.relationships,
    required this.contentTypes,
    required this.numbering,
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
          _ => 'application/octet-stream',
        };
  }
}

class _NumberingLevel {
  final DocxListType type;
  final int start;

  const _NumberingLevel({required this.type, required this.start});
}
