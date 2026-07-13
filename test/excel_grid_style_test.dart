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

  testWidgets('aligns general values according to their cell type', (
    tester,
  ) async {
    final sheet = ExcelSheet(
      name: 'General alignment',
      rowCount: 1,
      columnCount: 3,
      rows: [
        [
          const ExcelCell(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            rawValue: 'Fictional task',
            displayValue: 'Fictional task',
            type: ExcelCellType.string,
          ),
          const ExcelCell(
            rowIndex: 0,
            columnIndex: 1,
            address: 'B1',
            rawValue: '45678',
            displayValue: '1/21/25',
            type: ExcelCellType.number,
          ),
          const ExcelCell(
            rowIndex: 0,
            columnIndex: 2,
            address: 'C1',
            rawValue: '0.75',
            displayValue: '75%',
            type: ExcelCellType.number,
          ),
        ],
      ],
    );

    final grid = await pumpSheet(tester, sheet);

    expect(grid.debugTextAlignmentAt(0, 0), Alignment.bottomLeft);
    expect(grid.debugTextAlignmentAt(0, 1), Alignment.bottomRight);
    expect(grid.debugTextAlignmentAt(0, 2), Alignment.bottomRight);
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

  testWidgets('centers text across adjacent empty cells', (tester) async {
    tester.view.physicalSize = const Size(300, 600);
    addTearDown(tester.view.resetPhysicalSize);
    const centeredStyle = ExcelCellStyle(
      horizontalAlign: ExcelHorizontalAlign.centerContinuous,
    );
    final sheet = ExcelSheet(
      name: 'Centered title',
      rowCount: 1,
      columnCount: 4,
      rows: [
        [
          ExcelCell(
            rowIndex: 0,
            columnIndex: 0,
            address: 'A1',
            rawValue: 'Fictional project title',
            displayValue: 'Fictional project title',
            type: ExcelCellType.string,
            style: centeredStyle,
          ),
          ExcelCell.blank(
            rowIndex: 0,
            columnIndex: 1,
            address: 'B1',
            style: centeredStyle,
          ),
          ExcelCell.blank(
            rowIndex: 0,
            columnIndex: 2,
            address: 'C1',
            style: centeredStyle,
          ),
          ExcelCell(
            rowIndex: 0,
            columnIndex: 3,
            address: 'D1',
            rawValue: 'Stop',
            displayValue: 'Stop',
            type: ExcelCellType.string,
            style: centeredStyle,
          ),
        ],
      ],
    );

    final grid = await pumpSheet(tester, sheet);

    expect(grid.debugTextPaintRect(0, 0).width, 360);
    expect(grid.debugVisibleTextPaintRect(0, 0).width, greaterThan(0));
    expect(
      grid.debugVisibleTextPaintRect(0, 2),
      grid.debugVisibleTextPaintRect(0, 0),
    );
    expect(grid.debugTextPaintRect(0, 3).width, 120);
    expect(sheet.mergeRegions, isEmpty);
  });

  testWidgets('respects hidden worksheet grid lines', (tester) async {
    final sheet = ExcelSheet(
      name: 'Hidden grid lines',
      rowCount: 1,
      columnCount: 1,
      showGridLines: false,
      rows: [
        [ExcelCell.blank(rowIndex: 0, columnIndex: 0, address: 'A1')],
      ],
    );

    final grid = await pumpSheet(tester, sheet);

    expect(grid.debugShowsGridLines, isFalse);
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
