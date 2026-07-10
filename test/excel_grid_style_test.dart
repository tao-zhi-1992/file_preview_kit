import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

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

  testWidgets('renders cell font and background styles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(
            workbook: ExcelWorkbook(sheets: [styledSheet()]),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Header'));
    final textStyle = text.style!;

    expect(textStyle.fontWeight, FontWeight.w600);
    expect(textStyle.fontStyle, FontStyle.italic);
    expect(textStyle.fontSize, 16);
    expect(textStyle.fontFamily, 'Calibri');
    expect(textStyle.color, const Color(0xFFFF0000));
    expect(textStyle.decoration, TextDecoration.underline);

    final background = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('excel-cell-0-0')),
        matching: find.byType(ColoredBox),
      ),
    );

    expect(background.color, const Color(0xFFFFFF00));
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(workbook: ExcelWorkbook(sheets: [sheet])),
        ),
      ),
    );

    final background = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('excel-cell-0-0')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(background.color, const Color(0xFFFFFF00));
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(workbook: ExcelWorkbook(sheets: [sheet])),
        ),
      ),
    );

    expect(find.text('Merged title'), findsOneWidget);

    final mergedCells = tester
        .widgetList<TableViewCell>(find.byType(TableViewCell))
        .where((cell) => cell.columnMergeSpan == 3);
    expect(mergedCells, isNotEmpty);
    expect(mergedCells.first.columnMergeStart, 1);
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(workbook: ExcelWorkbook(sheets: [sheet])),
        ),
      ),
    );

    final table = tester.widget<TableView>(find.byType(TableView));
    final delegate = table.delegate as TableCellDelegateMixin;
    final wideColumn = delegate.buildColumn(2)!;
    final defaultColumn = delegate.buildColumn(1)!;

    expect((wideColumn.extent as FixedTableSpanExtent).pixels, 200);
    expect((defaultColumn.extent as FixedTableSpanExtent).pixels, 120);
  });
}
