import 'package:file_preview_kit/file_preview_kit.dart';
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
              fontSize: 16,
              fontColor: Color(0xFFFF0000),
              backgroundColor: Color(0xFFFFFF00),
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
    expect(textStyle.color, const Color(0xFFFF0000));

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const ValueKey('excel-cell-0-0')),
        matching: find.byType(Material),
      ),
    );

    expect(material.color, const Color(0xFFFFFF00));
  });
}
