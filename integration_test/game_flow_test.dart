import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shuffle_slide/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline guest can open Number Puzzle level one on Android', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    if (find.text('Continue as Guest').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Continue as Guest'));
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Play Number Puzzle'));
    await tester.tap(find.text('Play Number Puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s play'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('One tile closer.'), findsOneWidget);
    expect(find.text('TIME LEFT'), findsOneWidget);
  });
}
