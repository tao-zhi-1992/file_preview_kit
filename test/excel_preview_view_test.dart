import 'package:file_preview_kit/file_preview_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        home: Scaffold(body: ExcelPreviewView(workbook: workbook)),
      ),
    );

    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('A'), findsAtLeastNWidgets(1));
    expect(find.text('1'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Receipts'));
    await tester.pumpAndSettle();
    expect(find.text('Received'), findsOneWidget);
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
}
