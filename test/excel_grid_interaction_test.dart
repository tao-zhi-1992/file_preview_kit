import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:file_preview_kit/src/excel/widgets/excel_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _headerWidth = 56.0;
const _headerHeight = 36.0;
const _cellWidth = 120.0;
const _cellHeight = 36.0;

ExcelSheet _sampleSheet(String name) {
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

Future<void> _pumpSheet(WidgetTester tester, ExcelSheet sheet) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExcelPreviewView(workbook: ExcelWorkbook(sheets: [sheet])),
      ),
    ),
  );
}

ExcelGridViewState _grid(WidgetTester tester) =>
    tester.state<ExcelGridViewState>(find.byType(ExcelGridView));

ExcelGridViewState _gridNamed(WidgetTester tester, String name) => tester
    .stateList<ExcelGridViewState>(
      find.byType(ExcelGridView, skipOffstage: false),
    )
    .firstWhere((state) => state.widget.sheet.name == name);

Offset _gridOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ExcelGridView));

Future<void> _dragFrom(WidgetTester tester, Offset start, Offset delta) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(delta);
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('selects cells, columns, and rows exclusively', (tester) async {
    await _pumpSheet(tester, _sampleSheet('Selection sample'));
    final origin = _gridOrigin(tester);
    final grid = _grid(tester);

    await tester.tapAt(
      origin + const Offset(_headerWidth + 10, _headerHeight + 10),
    );
    await tester.pump();
    expect(grid.isCellSelected(0, 0), isTrue);
    expect(grid.debugColumnGripRect, isNull);
    expect(grid.debugRowGripRect, isNull);

    await tester.tapAt(
      origin + const Offset(_headerWidth + 10, _headerHeight / 2),
    );
    await tester.pump();
    expect(grid.isColumnSelected(0), isTrue);
    expect(grid.isCellSelected(0, 0), isFalse);
    expect(grid.isCellHighlighted(0, 0), isTrue);
    expect(grid.isCellHighlighted(1, 0), isTrue);
    expect(grid.isCellHighlighted(0, 1), isFalse);
    expect(grid.debugColumnGripRect, isNotNull);
    expect(grid.debugRowGripRect, isNull);

    await tester.tapAt(
      origin + const Offset(_headerWidth / 2, _headerHeight + 10),
    );
    await tester.pump();
    expect(grid.isRowSelected(0), isTrue);
    expect(grid.isColumnSelected(0), isFalse);
    expect(grid.isCellHighlighted(0, 1), isTrue);
    expect(grid.isCellHighlighted(1, 0), isFalse);
    expect(grid.debugRowGripRect, isNotNull);
    expect(grid.debugColumnGripRect, isNull);

    await tester.tapAt(
      origin + const Offset(_headerWidth / 2, _headerHeight / 2),
    );
    await tester.pump();
    expect(grid.isRowSelected(0), isFalse);
    expect(grid.isCellHighlighted(0, 0), isFalse);
    expect(grid.debugColumnGripRect, isNull);
    expect(grid.debugRowGripRect, isNull);
  });

  testWidgets('resizes a selected column with the header grip', (tester) async {
    await _pumpSheet(tester, _sampleSheet('Resize columns'));
    final origin = _gridOrigin(tester);
    final grid = _grid(tester);

    await tester.tapAt(
      origin + const Offset(_headerWidth + 10, _headerHeight / 2),
    );
    await tester.pump();
    final grip = grid.debugColumnGripRect ?? Rect.zero;
    expect(grip, isNot(Rect.zero));

    await _dragFrom(tester, origin + grip.center, const Offset(60, 0));
    expect(grid.columnWidthAt(0), _cellWidth + 60);
    expect(grid.debugScrollOffset, Offset.zero);

    final shrinkGrip = grid.debugColumnGripRect ?? Rect.zero;
    await _dragFrom(tester, origin + shrinkGrip.center, const Offset(-400, 0));
    expect(grid.columnWidthAt(0), 48);
  });

  testWidgets('resizes a selected row with the header grip', (tester) async {
    await _pumpSheet(tester, _sampleSheet('Resize rows'));
    final origin = _gridOrigin(tester);
    final grid = _grid(tester);

    await tester.tapAt(
      origin + const Offset(_headerWidth / 2, _headerHeight + 10),
    );
    await tester.pump();
    final grip = grid.debugRowGripRect ?? Rect.zero;
    expect(grip, isNot(Rect.zero));

    await _dragFrom(tester, origin + grip.center, const Offset(0, 40));
    expect(grid.rowHeightAt(0), _cellHeight + 40);
    expect(grid.debugScrollOffset, Offset.zero);

    final shrinkGrip = grid.debugRowGripRect ?? Rect.zero;
    await _dragFrom(tester, origin + shrinkGrip.center, const Offset(0, -400));
    expect(grid.rowHeightAt(0), 24);
  });

  testWidgets('pans the body to scroll the grid', (tester) async {
    await _pumpSheet(tester, _sampleSheet('Scroll sample'));
    final grid = _grid(tester);

    await tester.drag(
      find.byType(ExcelGridView),
      const Offset(-200, 0),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(grid.debugScrollOffset.dx, greaterThan(0));
    expect(grid.debugScrollOffset.dy, 0);
  });

  testWidgets('keeps sheet resize state while switching tabs', (tester) async {
    final workbook = ExcelWorkbook(
      sheets: [_sampleSheet('First sample'), _sampleSheet('Second sample')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExcelPreviewView(workbook: workbook)),
      ),
    );

    final origin = _gridOrigin(tester);
    await tester.tapAt(
      origin + const Offset(_headerWidth + 10, _headerHeight / 2),
    );
    await tester.pump();

    final firstGrid = _gridNamed(tester, 'First sample');
    final grip = firstGrid.debugColumnGripRect ?? Rect.zero;
    expect(grip, isNot(Rect.zero));
    await _dragFrom(tester, origin + grip.center, const Offset(60, 0));
    expect(firstGrid.columnWidthAt(0), _cellWidth + 60);

    await tester.tap(find.text('Second sample'));
    await tester.pumpAndSettle();
    expect(_gridNamed(tester, 'Second sample').columnWidthAt(0), _cellWidth);

    await tester.tap(find.text('First sample'));
    await tester.pumpAndSettle();
    expect(
      _gridNamed(tester, 'First sample').columnWidthAt(0),
      _cellWidth + 60,
    );
  });
}
