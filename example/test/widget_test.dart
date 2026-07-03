import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the file picker action', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Choose XLSX, CSV, or DOCX file'), findsOneWidget);
    final context = tester.element(find.text('Choose XLSX, CSV, or DOCX file'));
    expect(Theme.of(context).colorScheme.primary, Colors.black);
  });
}
