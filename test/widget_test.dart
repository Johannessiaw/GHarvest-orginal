import 'package:flutter_test/flutter_test.dart';
import 'package:gharvest/main.dart';

void main() {
  testWidgets('App starts with splash screen showing Get Started', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // Splash screen shows the brand and Get Started button
    expect(find.text('GHarvest'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.text("Fresh from Ghana's farms to your table."),
      findsOneWidget,
    );
  });
}
