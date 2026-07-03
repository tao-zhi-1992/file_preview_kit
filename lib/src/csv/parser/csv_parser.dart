import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' show Csv;

import '../../core/preview_exception.dart';
import '../../excel/models/excel_cell.dart';
import '../../excel/models/excel_cell_type.dart';
import '../../excel/models/excel_sheet.dart';
import '../../excel/models/excel_workbook.dart';

/// Parses UTF-8 CSV bytes into an [ExcelWorkbook].
class CsvParser {
  /// Parses [bytes] and returns a single-sheet workbook.
  ExcelWorkbook parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const EmptyFileException();
    }

    try {
      final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
      final values = Csv(skipEmptyLines: false).decode(text);
      final columnCount = values.fold<int>(
        0,
        (count, row) => row.length > count ? row.length : count,
      );
      final rows = <List<ExcelCell>>[];

      for (var rowIndex = 0; rowIndex < values.length; rowIndex++) {
        final row = values[rowIndex];
        rows.add(
          List.generate(columnCount, (columnIndex) {
            final value = columnIndex < row.length
                ? row[columnIndex] as String
                : '';
            final address = _cellAddress(rowIndex, columnIndex);

            if (value.isEmpty) {
              return ExcelCell.blank(
                rowIndex: rowIndex,
                columnIndex: columnIndex,
                address: address,
              );
            }

            return ExcelCell(
              rowIndex: rowIndex,
              columnIndex: columnIndex,
              address: address,
              rawValue: value,
              displayValue: value,
              type: ExcelCellType.string,
            );
          }),
        );
      }

      return ExcelWorkbook(
        sheets: [
          ExcelSheet(
            name: 'CSV',
            rowCount: rows.length,
            columnCount: columnCount,
            rows: rows,
          ),
        ],
      );
    } on PreviewException {
      rethrow;
    } catch (_) {
      throw const InvalidCsvException();
    }
  }

  String _cellAddress(int rowIndex, int columnIndex) {
    var index = columnIndex + 1;
    final chars = <String>[];

    while (index > 0) {
      chars.insert(0, String.fromCharCode(65 + (index - 1) % 26));
      index = (index - 1) ~/ 26;
    }

    return '${chars.join()}${rowIndex + 1}';
  }
}
