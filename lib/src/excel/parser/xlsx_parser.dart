import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/preview_exception.dart';
import '../models/excel_cell.dart';
import '../models/excel_cell_type.dart';
import '../models/excel_sheet.dart';
import '../models/excel_workbook.dart';

/// Parses XLSX package bytes into an [ExcelWorkbook].
class XlsxParser {
  /// Parses [bytes] and returns worksheets in workbook order.
  ExcelWorkbook parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const EmptyFileException();
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      if (_isPasswordProtected(archive)) {
        throw const PasswordProtectedFileException();
      }

      final sharedStringsXml = _readArchiveText(
        archive,
        'xl/sharedStrings.xml',
      );

      final sharedStrings = sharedStringsXml == null
          ? <String>[]
          : _parseSharedStrings(sharedStringsXml);

      final workbookXml = _readArchiveText(archive, 'xl/workbook.xml');
      final relationshipsXml = _readArchiveText(
        archive,
        'xl/_rels/workbook.xml.rels',
      );

      if (workbookXml == null || relationshipsXml == null) {
        throw const InvalidXlsxException();
      }

      final sheetInfos = _parseWorkbookSheets(workbookXml);
      final relationshipMap = _parseWorkbookRelationships(relationshipsXml);
      final sheets = <ExcelSheet>[];

      for (final sheetInfo in sheetInfos) {
        final target = relationshipMap[sheetInfo.relationshipId];

        if (target == null) {
          continue;
        }

        final sheetXml = _readArchiveText(archive, target);

        if (sheetXml == null) {
          continue;
        }

        sheets.add(
          _parseWorksheet(
            sheetXml,
            sheetName: sheetInfo.name,
            sharedStrings: sharedStrings,
          ),
        );
      }

      return ExcelWorkbook(sheets: sheets);
    } on PreviewException {
      rethrow;
    } catch (_) {
      throw const InvalidXlsxException();
    }
  }

  bool _isPasswordProtected(Archive archive) {
    for (final file in archive.files) {
      if (file.name == 'EncryptedPackage') {
        return true;
      }
    }

    return false;
  }

  String? _readArchiveText(Archive archive, String path) {
    for (final file in archive.files) {
      if (file.name == path) {
        final content = file.content;

        if (content is List<int>) {
          return utf8.decode(content);
        }

        return content.toString();
      }
    }

    return null;
  }

  List<String> _parseSharedStrings(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final result = <String>[];

    for (final si in document.findAllElements('si')) {
      final text = si.findAllElements('t').map((e) => e.innerText).join();
      result.add(text);
    }

    return result;
  }

  List<_WorkbookSheetInfo> _parseWorkbookSheets(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final result = <_WorkbookSheetInfo>[];

    for (final sheetElement in document.findAllElements('sheet')) {
      final name = sheetElement.getAttribute('name') ?? '';
      final relationshipId = _getRelationshipId(sheetElement);

      if (name.isEmpty || relationshipId.isEmpty) {
        continue;
      }

      result.add(
        _WorkbookSheetInfo(name: name, relationshipId: relationshipId),
      );
    }

    return result;
  }

  String _getRelationshipId(XmlElement element) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == 'id') {
        return attribute.value;
      }
    }

    return '';
  }

  Map<String, String> _parseWorkbookRelationships(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final result = <String, String>{};

    for (final relationshipElement in document.findAllElements(
      'Relationship',
    )) {
      final id = relationshipElement.getAttribute('Id');
      final target = relationshipElement.getAttribute('Target');

      if (id == null || target == null) {
        continue;
      }

      result[id] = _normalizeWorkbookTargetPath(target);
    }

    return result;
  }

  String _normalizeWorkbookTargetPath(String target) {
    if (target.startsWith('/')) {
      return target.substring(1);
    }

    if (target.startsWith('xl/')) {
      return target;
    }

    return 'xl/$target';
  }

  ExcelSheet _parseWorksheet(
    String xmlText, {
    required String sheetName,
    required List<String> sharedStrings,
  }) {
    final document = XmlDocument.parse(xmlText);

    final rowMap = <int, List<ExcelCell>>{};
    var maxColumnCount = 0;
    var maxRowIndex = -1;

    for (final rowElement in document.findAllElements('row')) {
      final rowCells = <ExcelCell>[];

      final rowIndexFromAttr = _rowIndexFromRowElement(rowElement);

      for (final cellElement in rowElement.findElements('c')) {
        final address = cellElement.getAttribute('r') ?? '';

        final rowIndex = address.isEmpty
            ? rowIndexFromAttr
            : _rowIndexFromCellRef(address);

        final columnIndex = address.isEmpty
            ? rowCells.length
            : _columnIndexFromCellRef(address);

        while (rowCells.length < columnIndex) {
          final blankColumnIndex = rowCells.length;

          rowCells.add(
            ExcelCell.blank(
              rowIndex: rowIndex,
              columnIndex: blankColumnIndex,
              address: _cellAddress(rowIndex, blankColumnIndex),
            ),
          );
        }

        final cell = _parseCell(
          cellElement,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          address: address.isEmpty
              ? _cellAddress(rowIndex, columnIndex)
              : address,
          sharedStrings: sharedStrings,
        );

        rowCells.add(cell);

        if (columnIndex + 1 > maxColumnCount) {
          maxColumnCount = columnIndex + 1;
        }

        if (rowIndex > maxRowIndex) {
          maxRowIndex = rowIndex;
        }
      }

      if (rowCells.isNotEmpty) {
        final rowIndex = rowCells.first.rowIndex;
        rowMap[rowIndex] = rowCells;
      }
    }

    final rows = <List<ExcelCell>>[];

    for (var rowIndex = 0; rowIndex <= maxRowIndex; rowIndex++) {
      final existingRow = rowMap[rowIndex];

      if (existingRow == null) {
        rows.add(_blankRow(rowIndex: rowIndex, columnCount: maxColumnCount));
        continue;
      }

      final normalizedRow = List<ExcelCell>.from(existingRow);

      while (normalizedRow.length < maxColumnCount) {
        final columnIndex = normalizedRow.length;

        normalizedRow.add(
          ExcelCell.blank(
            rowIndex: rowIndex,
            columnIndex: columnIndex,
            address: _cellAddress(rowIndex, columnIndex),
          ),
        );
      }

      rows.add(normalizedRow);
    }

    return ExcelSheet(
      name: sheetName,
      rowCount: rows.length,
      columnCount: maxColumnCount,
      rows: rows,
    );
  }

  List<ExcelCell> _blankRow({required int rowIndex, required int columnCount}) {
    return List.generate(columnCount, (columnIndex) {
      return ExcelCell.blank(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        address: _cellAddress(rowIndex, columnIndex),
      );
    });
  }

  ExcelCell _parseCell(
    XmlElement cellElement, {
    required int rowIndex,
    required int columnIndex,
    required String address,
    required List<String> sharedStrings,
  }) {
    final type = cellElement.getAttribute('t');
    final valueElements = cellElement.findElements('v');
    final rawValue = valueElements.isEmpty ? '' : valueElements.first.innerText;

    if (type == 's') {
      final index = int.tryParse(rawValue);

      final displayValue =
          index == null || index < 0 || index >= sharedStrings.length
          ? ''
          : sharedStrings[index];

      return ExcelCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        address: address,
        rawValue: rawValue,
        displayValue: displayValue,
        type: ExcelCellType.string,
      );
    }

    if (type == 'inlineStr') {
      final displayValue = cellElement
          .findAllElements('t')
          .map((e) => e.innerText)
          .join();

      return ExcelCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        address: address,
        rawValue: displayValue,
        displayValue: displayValue,
        type: ExcelCellType.string,
      );
    }

    if (type == 'b') {
      final displayValue = rawValue == '1' ? 'TRUE' : 'FALSE';

      return ExcelCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        address: address,
        rawValue: rawValue,
        displayValue: displayValue,
        type: ExcelCellType.boolean,
      );
    }

    if (type == 'e') {
      return ExcelCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        address: address,
        rawValue: rawValue,
        displayValue: rawValue,
        type: ExcelCellType.error,
      );
    }

    return ExcelCell(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      address: address,
      rawValue: rawValue,
      displayValue: rawValue,
      type: rawValue.isEmpty ? ExcelCellType.blank : ExcelCellType.number,
    );
  }

  int _columnIndexFromCellRef(String ref) {
    final letters = ref.replaceAll(RegExp(r'\d'), '');

    var result = 0;

    for (final codeUnit in letters.codeUnits) {
      result = result * 26 + (codeUnit - 'A'.codeUnitAt(0) + 1);
    }

    return result - 1;
  }

  int _rowIndexFromCellRef(String ref) {
    final digits = ref.replaceAll(RegExp(r'[A-Z]'), '');
    final rowNumber = int.tryParse(digits) ?? 1;
    return rowNumber - 1;
  }

  int _rowIndexFromRowElement(XmlElement rowElement) {
    final rowNumberText = rowElement.getAttribute('r');
    final rowNumber = int.tryParse(rowNumberText ?? '') ?? 1;
    return rowNumber - 1;
  }

  String _cellAddress(int rowIndex, int columnIndex) {
    return '${_columnName(columnIndex)}${rowIndex + 1}';
  }

  String _columnName(int columnIndex) {
    var index = columnIndex + 1;
    final chars = <String>[];

    while (index > 0) {
      final remainder = (index - 1) % 26;
      chars.insert(0, String.fromCharCode('A'.codeUnitAt(0) + remainder));
      index = (index - 1) ~/ 26;
    }

    return chars.join();
  }
}

class _WorkbookSheetInfo {
  final String name;
  final String relationshipId;

  const _WorkbookSheetInfo({required this.name, required this.relationshipId});
}
