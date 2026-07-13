import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows file picker and demo file actions', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Choose XLSX, CSV, or DOCX file'), findsOneWidget);
    expect(find.text('Open project management demo'), findsOneWidget);
    expect(find.text('Open large XLSX demo'), findsOneWidget);
    expect(find.text('Open DOCX demo'), findsOneWidget);
    final context = tester.element(find.text('Choose XLSX, CSV, or DOCX file'));
    expect(Theme.of(context).colorScheme.primary, Colors.black);
  });

  testWidgets('opens a bundled demo file', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Open project management demo'));
    await tester.pumpAndSettle();

    expect(find.text('Open project management demo'), findsNothing);
  });
}
