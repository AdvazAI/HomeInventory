import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_inventory/main.dart';

void main() {
  testWidgets('Home Inventory App renders Profile Selection smoke test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        const ProviderScope(
          child: HomeInventoryApp(),
        ),
      );

      // Verify that we display the title "Who's Using the App?"
      expect(find.text("Who's Using the App?"), findsOneWidget);
    });
  });
}
