import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:file_preview_kit/src/excel/widgets/excel_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExcelSheet styledSheet() {
    return ExcelSheet(
      name: 'Styled',
      rowCount: 1,
      columnCount: 1,
      rows: [
        [
          ExcelCell(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            rawValue: 'Header',
            displayValue: 'Header',
            type: ExcelCellType.string,
            style: const ExcelCellStyle(
              bold: true,
              italic: true,
              underline: true,
              fontSize: 16,
              fontFamily: 'Calibri',
              fontColor: Color(0xFFFF0000),
              backgroundColor: Color(0xFFFFFF00),
              horizontalAlign: ExcelHorizontalAlign.center,
              verticalAlign: ExcelVerticalAlign.center,
              wrapText: true,
              borders: ExcelCellBorders(
                left: BorderSide(color: Color(0xFF0000FF)),
                right: BorderSide(color: Color(0xFF0000FF)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<ExcelGridViewState> pumpSheet(
    WidgetTester tester,
    ExcelSheet sheet,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(workbook: ExcelWorkbook(sheets: [sheet])),
        ),
      ),
    );
    return tester.state<ExcelGridViewState>(find.byType(ExcelGridView));
  }

  testWidgets('renders cell font and background styles', (tester) async {
    final grid = await pumpSheet(tester, styledSheet());

    final textStyle = grid.debugTextStyleAt(0, 0);
    expect(textStyle.fontWeight, FontWeight.w600);
    expect(textStyle.fontStyle, FontStyle.italic);
    expect(textStyle.fontSize, 16);
    expect(textStyle.fontFamily, 'Calibri');
    expect(textStyle.color, const Color(0xFFFF0000));
    expect(textStyle.decoration, TextDecoration.underline);

    expect(grid.debugCellBackgroundAt(0, 0), const Color(0xFFFFFF00));
  });

  testWidgets('renders background styles on blank cells', (tester) async {
    final sheet = ExcelSheet(
      name: 'Blank style',
      rowCount: 1,
      columnCount: 1,
      rows: [
        [
          ExcelCell.blank(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            style: const ExcelCellStyle(backgroundColor: Color(0xFFFFFF00)),
          ),
        ],
      ],
    );

    final grid = await pumpSheet(tester, sheet);
    expect(grid.debugCellBackgroundAt(0, 0), const Color(0xFFFFFF00));
  });

  testWidgets('renders merged cells from worksheet metadata', (tester) async {
    final sheet = ExcelSheet(
      name: 'Merged',
      rowCount: 1,
      columnCount: 3,
      mergeRegions: const [
        ExcelMergeRegion(startRow: 0, startColumn: 0, endRow: 0, endColumn: 2),
      ],
      rows: [
        [
          ExcelCell(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            rawValue: 'Merged title',
            displayValue: 'Merged title',
            type: ExcelCellType.string,
          ),
          ExcelCell.blank(rowIndex: 0, columnIndex: 1, address: 'B1'),
          ExcelCell.blank(rowIndex: 0, columnIndex: 2, address: 'C1'),
        ],
      ],
    );

    final grid = await pumpSheet(tester, sheet);

    expect(grid.debugDisplayValueAt(0, 2), 'Merged title');
    expect(grid.debugCellPaintRect(0, 0), grid.debugCellPaintRect(0, 2));
    expect(grid.debugCellPaintRect(0, 0).width, 360);

    // Internal vertical dividers inside A1:C1 are skipped; outer edge remains.
    expect(grid.debugSkipsVerticalDivider(afterColumn: 0, rowIndex: 0), isTrue);
    expect(grid.debugSkipsVerticalDivider(afterColumn: 1, rowIndex: 0), isTrue);
    expect(
      grid.debugSkipsVerticalDivider(afterColumn: 2, rowIndex: 0),
      isFalse,
    );
  });

  testWidgets('skips internal dividers for vertically merged cells', (
    tester,
  ) async {
    final sheet = ExcelSheet(
      name: 'Vertical merge',
      rowCount: 3,
      columnCount: 1,
      mergeRegions: const [
        ExcelMergeRegion(startRow: 0, startColumn: 0, endRow: 2, endColumn: 0),
      ],
      rows: [
        [
          ExcelCell(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            rawValue: 'Tall',
            displayValue: 'Tall',
            type: ExcelCellType.string,
          ),
        ],
        [ExcelCell.blank(rowIndex: 1, columnIndex: 0, address: 'A2')],
        [ExcelCell.blank(rowIndex: 2, columnIndex: 0, address: 'A3')],
      ],
    );

    final grid = await pumpSheet(tester, sheet);

    expect(grid.debugCellPaintRect(0, 0).height, 108);
    expect(
      grid.debugSkipsHorizontalDivider(afterRow: 0, columnIndex: 0),
      isTrue,
    );
    expect(
      grid.debugSkipsHorizontalDivider(afterRow: 1, columnIndex: 0),
      isTrue,
    );
    expect(
      grid.debugSkipsHorizontalDivider(afterRow: 2, columnIndex: 0),
      isFalse,
    );
  });

  testWidgets('uses worksheet column widths as initial sizes', (tester) async {
    final sheet = ExcelSheet(
      name: 'Widths',
      rowCount: 1,
      columnCount: 2,
      columnWidths: const {1: 200},
      rows: [
        [
          ExcelCell(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            rawValue: 'A',
            displayValue: 'A',
            type: ExcelCellType.string,
          ),
          ExcelCell(
            rowIndex: 0,
            columnIndex: 1,
            address: 'B1',
            rawValue: 'Wide',
            displayValue: 'Wide',
            type: ExcelCellType.string,
          ),
        ],
      ],
    );

    final grid = await pumpSheet(tester, sheet);

    expect(grid.columnWidthAt(1), 200);
    expect(grid.columnWidthAt(0), 120);
  });
}
