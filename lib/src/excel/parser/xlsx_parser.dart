import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/preview_exception.dart';
import '../models/excel_cell.dart';
import '../models/excel_cell_style.dart';
import '../models/excel_cell_type.dart';
import '../models/excel_merge_region.dart';
import '../models/excel_sheet.dart';
import '../models/excel_styles_parse_result.dart';
import '../models/excel_workbook.dart';
import 'excel_column_width.dart';
import 'excel_number_format.dart';
import 'excel_theme_colors.dart';
import 'styles_reader.dart';

/// Parses XLSX package bytes into an [ExcelWorkbook].
class XlsxParser {
  /// Creates an XLSX parser.
  const XlsxParser();

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

      final themeXml = _readThemeXml(archive, relationshipsXml);
      final themeColors = ExcelThemeColors.parse(themeXml);

      final stylesXml = _readArchiveText(archive, 'xl/styles.xml');

      final stylesResult = stylesXml == null
          ? ExcelStylesParseResult.empty
          : StylesReader().parse(stylesXml, themeColors: themeColors);

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
            stylesResult: stylesResult,
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

  String? _readThemeXml(Archive archive, String relationshipsXml) {
    final document = XmlDocument.parse(relationshipsXml);

    for (final relationshipElement in document.findAllElements(
      'Relationship',
    )) {
      final type = relationshipElement.getAttribute('Type') ?? '';
      if (!type.endsWith('/theme')) {
        continue;
      }

      final target = relationshipElement.getAttribute('Target');
      if (target == null) {
        continue;
      }

      final path = _normalizeWorkbookTargetPath(target);
      return _readArchiveText(archive, path);
    }

    return _readArchiveText(archive, 'xl/theme/theme1.xml');
  }

  ExcelSheet _parseWorksheet(
    String xmlText, {
    required String sheetName,
    required List<String> sharedStrings,
    required ExcelStylesParseResult stylesResult,
  }) {
    final document = XmlDocument.parse(xmlText);

    final columnWidths = _parseColumnWidths(document);
    final mergeRegions = _parseMergeRegions(document);
    final columnStyles = _parseColumnStyles(document, stylesResult.styles);
    final showGridLines =
        document
            .findAllElements('sheetView')
            .firstOrNull
            ?.getAttribute('showGridLines') !=
        '0';

    final rowMap = <int, List<ExcelCell>>{};
    final rowStyles = <int, ExcelCellStyle>{};
    var maxColumnCount = 0;
    var maxRowIndex = -1;

    for (final rowElement in document.findAllElements('row')) {
      final rowCells = <ExcelCell>[];

      final rowIndexFromAttr = _rowIndexFromRowElement(rowElement);
      final rowStyle = _styleAt(
        stylesResult.styles,
        int.tryParse(rowElement.getAttribute('s') ?? ''),
      );
      if (rowStyle != null) {
        rowStyles[rowIndexFromAttr] = rowStyle;
      }

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
              style:
                  rowStyle ??
                  columnStyles[blankColumnIndex] ??
                  ExcelCellStyle.empty,
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
          stylesResult: stylesResult,
          inheritedStyle:
              rowStyle ?? columnStyles[columnIndex] ?? ExcelCellStyle.empty,
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
        rows.add(
          _blankRow(
            rowIndex: rowIndex,
            columnCount: maxColumnCount,
            rowStyle: rowStyles[rowIndex],
            columnStyles: columnStyles,
          ),
        );
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
            style:
                rowStyles[rowIndex] ??
                columnStyles[columnIndex] ??
                ExcelCellStyle.empty,
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
      columnWidths: columnWidths,
      mergeRegions: mergeRegions,
      showGridLines: showGridLines,
    );
  }

  Map<int, double> _parseColumnWidths(XmlDocument document) {
    final result = <int, double>{};

    for (final col in document.findAllElements('col')) {
      final min = int.tryParse(col.getAttribute('min') ?? '') ?? 0;
      final max = int.tryParse(col.getAttribute('max') ?? '') ?? min;
      final width = double.tryParse(col.getAttribute('width') ?? '');
      if (width == null) {
        continue;
      }

      final pixels = excelColumnWidthToPixels(width);
      for (var column = min; column <= max; column++) {
        result[column - 1] = pixels;
      }
    }

    return result;
  }

  Map<int, ExcelCellStyle> _parseColumnStyles(
    XmlDocument document,
    List<ExcelCellStyle> styles,
  ) {
    final result = <int, ExcelCellStyle>{};

    for (final column in document.findAllElements('col')) {
      final style = _styleAt(
        styles,
        int.tryParse(column.getAttribute('style') ?? ''),
      );
      if (style == null) {
        continue;
      }

      final min = int.tryParse(column.getAttribute('min') ?? '') ?? 0;
      final max = int.tryParse(column.getAttribute('max') ?? '') ?? min;
      for (var index = min; index <= max; index++) {
        result[index - 1] = style;
      }
    }

    return result;
  }

  List<ExcelMergeRegion> _parseMergeRegions(XmlDocument document) {
    final result = <ExcelMergeRegion>[];

    for (final mergeCell in document.findAllElements('mergeCell')) {
      final ref = mergeCell.getAttribute('ref');
      if (ref == null || !ref.contains(':')) {
        continue;
      }

      final parts = ref.split(':');
      if (parts.length != 2) {
        continue;
      }

      final startRow = _rowIndexFromCellRef(parts[0]);
      final startColumn = _columnIndexFromCellRef(parts[0]);
      final endRow = _rowIndexFromCellRef(parts[1]);
      final endColumn = _columnIndexFromCellRef(parts[1]);

      result.add(
        ExcelMergeRegion(
          startRow: startRow,
          startColumn: startColumn,
          endRow: endRow,
          endColumn: endColumn,
        ),
      );
    }

    return result;
  }

  List<ExcelCell> _blankRow({
    required int rowIndex,
    required int columnCount,
    required ExcelCellStyle? rowStyle,
    required Map<int, ExcelCellStyle> columnStyles,
  }) {
    return List.generate(columnCount, (columnIndex) {
      return ExcelCell.blank(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        address: _cellAddress(rowIndex, columnIndex),
        style: rowStyle ?? columnStyles[columnIndex] ?? ExcelCellStyle.empty,
      );
    });
  }

  ExcelCell _parseCell(
    XmlElement cellElement, {
    required int rowIndex,
    required int columnIndex,
    required String address,
    required List<String> sharedStrings,
    required ExcelStylesParseResult stylesResult,
    required ExcelCellStyle inheritedStyle,
  }) {
    final type = cellElement.getAttribute('t');
    final valueElements = cellElement.findElements('v');
    final rawValue = valueElements.isEmpty ? '' : valueElements.first.innerText;

    final styleIndex = int.tryParse(cellElement.getAttribute('s') ?? '');
    final style =
        styleIndex != null &&
            styleIndex >= 0 &&
            styleIndex < stylesResult.styles.length
        ? stylesResult.styles[styleIndex]
        : inheritedStyle;
    final numberFormat =
        styleIndex != null &&
            styleIndex >= 0 &&
            styleIndex < stylesResult.numberFormats.length
        ? stylesResult.numberFormats[styleIndex]
        : null;

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
        style: style,
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
        style: style,
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
        style: style,
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
        style: style,
      );
    }

    return ExcelCell(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      address: address,
      rawValue: rawValue,
      displayValue: ExcelNumberFormat.format(rawValue, numberFormat),
      type: rawValue.isEmpty ? ExcelCellType.blank : ExcelCellType.number,
      style: style,
    );
  }

  ExcelCellStyle? _styleAt(List<ExcelCellStyle> styles, int? index) {
    return index != null && index >= 0 && index < styles.length
        ? styles[index]
        : null;
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
