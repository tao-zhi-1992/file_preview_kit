import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  ExcelSheet sampleSheet(String name) {
    return ExcelSheet(
      name: name,
      rowCount: 3,
      columnCount: 3,
      rows: List.generate(
        3,
        (row) => List.generate(
          3,
          (column) => ExcelCell(
            rowIndex: row,
            columnIndex: column,
            address: 'R${row + 1}C${column + 1}',
            rawValue: 'Sample',
            displayValue: 'Sample',
            type: ExcelCellType.string,
          ),
        ),
      ),
    );
  }

  Future<void> pumpSheet(WidgetTester tester, ExcelSheet sheet) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(workbook: ExcelWorkbook(sheets: [sheet])),
        ),
      ),
    );
  }

  bool isSelected(WidgetTester tester, Key key) {
    final semantics = tester.widget<Semantics>(
      find
          .descendant(of: find.byKey(key), matching: find.byType(Semantics))
          .first,
    );
    return semantics.properties.selected ?? false;
  }

  double columnWidth(WidgetTester tester, int columnIndex) {
    final table = tester.widget<TableView>(find.byType(TableView));
    final delegate = table.delegate as TableCellDelegateMixin;
    final span = delegate.buildColumn(columnIndex + 1)!;
    return (span.extent as FixedTableSpanExtent).pixels;
  }

  double rowHeight(WidgetTester tester, int rowIndex) {
    final table = tester.widget<TableView>(find.byType(TableView));
    final delegate = table.delegate as TableCellDelegateMixin;
    final span = delegate.buildRow(rowIndex + 1)!;
    return (span.extent as FixedTableSpanExtent).pixels;
  }

  testWidgets('selects cells, columns, and rows exclusively', (tester) async {
    await pumpSheet(tester, sampleSheet('Selection sample'));

    await tester.tap(find.byKey(const ValueKey('excel-cell-0-0')));
    await tester.pump();

    expect(isSelected(tester, const ValueKey('excel-cell-0-0')), isTrue);
    expect(
      find.byKey(const ValueKey('excel-column-resize-handle-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-handle-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('excel-column-header-0')));
    await tester.pump();

    expect(isSelected(tester, const ValueKey('excel-column-header-0')), isTrue);
    expect(isSelected(tester, const ValueKey('excel-cell-0-0')), isTrue);
    expect(isSelected(tester, const ValueKey('excel-cell-1-0')), isTrue);
    expect(isSelected(tester, const ValueKey('excel-cell-0-1')), isFalse);
    expect(
      find.byKey(const ValueKey('excel-column-resize-handle-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-handle-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('excel-row-header-0')));
    await tester.pump();

    expect(isSelected(tester, const ValueKey('excel-row-header-0')), isTrue);
    expect(isSelected(tester, const ValueKey('excel-cell-0-0')), isTrue);
    expect(isSelected(tester, const ValueKey('excel-cell-0-1')), isTrue);
    expect(isSelected(tester, const ValueKey('excel-cell-1-0')), isFalse);
    expect(
      find.byKey(const ValueKey('excel-column-resize-handle-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-handle-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('excel-grid-corner')));
    await tester.pump();

    expect(isSelected(tester, const ValueKey('excel-cell-0-0')), isFalse);
    expect(
      find.byKey(const ValueKey('excel-row-resize-handle-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsNothing,
    );
  });

  testWidgets('resizes a selected column with an indicator', (tester) async {
    await pumpSheet(tester, sampleSheet('Column resize sample'));
    await tester.tap(find.byKey(const ValueKey('excel-column-header-0')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsOneWidget,
    );
    expect(columnWidth(tester, 0), 120);
    final handle = find.byKey(const ValueKey('excel-column-resize-handle-0'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(columnWidth(tester, 0), 160);
    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('excel-column-resize-indicator')),
      findsOneWidget,
    );
    expect(columnWidth(tester, 0), 160);

    final minimumGesture = await tester.startGesture(tester.getCenter(handle));
    await minimumGesture.moveBy(const Offset(-500, 0));
    await tester.pump();
    expect(columnWidth(tester, 0), 48);
    await minimumGesture.up();
  });

  testWidgets('resizes a selected row with an indicator', (tester) async {
    await pumpSheet(tester, sampleSheet('Row resize sample'));
    await tester.tap(find.byKey(const ValueKey('excel-row-header-0')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsOneWidget,
    );
    expect(rowHeight(tester, 0), 36);
    final handle = find.byKey(const ValueKey('excel-row-resize-handle-0'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();

    expect(rowHeight(tester, 0), 56);
    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('excel-row-resize-indicator')),
      findsOneWidget,
    );

    final minimumGesture = await tester.startGesture(tester.getCenter(handle));
    await minimumGesture.moveBy(const Offset(0, -500));
    await tester.pump();
    expect(rowHeight(tester, 0), 24);
    await minimumGesture.up();
  });

  testWidgets('keeps sheet resize state while switching tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExcelPreviewView(
            workbook: ExcelWorkbook(
              sheets: [
                sampleSheet('First sample'),
                sampleSheet('Second sample'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('excel-column-header-0')));
    await tester.pump();
    final handle = find.byKey(const ValueKey('excel-column-resize-handle-0'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(columnWidth(tester, 0), 160);

    await tester.tap(find.text('Second sample'));
    await tester.pumpAndSettle();
    expect(columnWidth(tester, 0), 120);

    await tester.tap(find.text('First sample'));
    await tester.pumpAndSettle();
    expect(columnWidth(tester, 0), 160);
    expect(
      find.byKey(const ValueKey('excel-column-resize-handle-0')),
      findsOneWidget,
    );
  });
}
