import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the file picker action', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Choose XLSX file'), findsOneWidget);
  });
}
