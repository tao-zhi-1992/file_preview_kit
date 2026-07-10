import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  testWidgets('switches between workbook sheets', (tester) async {
    ExcelSheet sheet(String name, String value) {
      final cell = ExcelCell(
        rowIndex: 0,
        columnIndex: 0,
        address: 'A1',
        rawValue: value,
        displayValue: value,
        type: ExcelCellType.string,
      );
      return ExcelSheet(
        name: name,
        rowCount: 1,
        columnCount: 1,
        rows: [
          [cell],
        ],
      );
    }

    final workbook = ExcelWorkbook(
      sheets: [sheet('Inventory', 'Stock'), sheet('Receipts', 'Received')],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        home: Scaffold(body: ExcelPreviewView(workbook: workbook)),
      ),
    );

    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('A'), findsAtLeastNWidgets(1));
    expect(find.text('1'), findsAtLeastNWidgets(1));

    final firstTabSize = tester.getSize(
      find.byKey(const ValueKey('sheet-tab-0')),
    );
    final secondTabSize = tester.getSize(
      find.byKey(const ValueKey('sheet-tab-1')),
    );
    AnimatedContainer dot(int index) => tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('sheet-tab-dot-$index')),
    );
    Color? dotColor(int index) =>
        (dot(index).decoration as BoxDecoration).color;
    final primaryColor = Theme.of(
      tester.element(find.byKey(const ValueKey('sheet-tab-0'))),
    ).colorScheme.primary;

    expect(primaryColor, Colors.black);
    expect(dotColor(0), primaryColor);
    expect(dotColor(1), Colors.transparent);
    expect(dot(0).duration, const Duration(milliseconds: 180));

    await tester.tap(find.text('Receipts'));
    await tester.pumpAndSettle();

    expect(find.text('Received'), findsOneWidget);
    expect(dotColor(0), Colors.transparent);
    expect(dotColor(1), primaryColor);
    expect(
      tester.getSize(find.byKey(const ValueKey('sheet-tab-0'))),
      firstTabSize,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('sheet-tab-1'))),
      secondTabSize,
    );
  });

  testWidgets('applies an explicit plugin theme', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
      ).copyWith(primary: Colors.green),
      useMaterial3: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: ExcelPreviewView(
            workbook: const ExcelWorkbook(
              sheets: [
                ExcelSheet(
                  name: 'Sample',
                  rowCount: 1,
                  columnCount: 1,
                  rows: [
                    [
                      ExcelCell(
                        rowIndex: 0,
                        columnIndex: 0,
                        address: 'A1',
                        rawValue: 'Value',
                        displayValue: 'Value',
                        type: ExcelCellType.string,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            theme: theme,
          ),
        ),
      ),
    );

    final dot = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('sheet-tab-dot-0')),
    );
    expect((dot.decoration as BoxDecoration).color, Colors.green);
  });

  testWidgets('uses localized empty workbook and sheet messages', (
    tester,
  ) async {
    const texts = FilePreviewKitTexts.zhHans();

    await tester.pumpWidget(
      const MaterialApp(
        home: ExcelPreviewView(
          workbook: ExcelWorkbook(sheets: []),
          texts: texts,
        ),
      ),
    );
    expect(find.text(texts.noSheetsFound), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(
            workbook: ExcelWorkbook(
              sheets: [
                ExcelSheet(
                  name: 'Empty sample',
                  rowCount: 0,
                  columnCount: 0,
                  rows: [],
                ),
              ],
            ),
            texts: texts,
          ),
        ),
      ),
    );
    expect(find.text(texts.emptySheet), findsOneWidget);
  });

  testWidgets('pins headers and lazily builds table cells', (tester) async {
    final row = List.generate(
      50,
      (column) =>
          ExcelCell.blank(rowIndex: 0, columnIndex: column, address: 'A1'),
    );
    final sheet = ExcelSheet(
      name: 'Large sample',
      rowCount: 200,
      columnCount: 50,
      rows: List.generate(200, (_) => row),
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

    expect(delegate.pinnedRowCount, 1);
    expect(delegate.pinnedColumnCount, 1);
    expect(delegate.rowCount, 211);
    expect(delegate.columnCount, 61);
    expect(delegate.buildRow(210), isNotNull);
    expect(delegate.buildColumn(60), isNotNull);
    expect(find.byType(TableViewCell).evaluate().length, lessThan(500));
  });
}
