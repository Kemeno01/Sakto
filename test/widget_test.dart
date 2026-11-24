import 'package:flutter_test/flutter_test.dart';
import 'package:spent_to_sawa/main.dart';

void main() {
  testWidgets('SpentApp renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SpentApp());
    expect(find.text('Active total'), findsOneWidget);
  });
}