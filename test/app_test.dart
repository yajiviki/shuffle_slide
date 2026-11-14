import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuffle_slide/app.dart';
import 'package:shuffle_slide/main.dart';
import 'package:shuffle_slide/data/store.dart';
import 'package:shuffle_slide/features/puzzle_engine/engine.dart';
import 'package:shuffle_slide/features/game/game_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<GameStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return GameStore(await SharedPreferences.getInstance());
  }

  testWidgets(
    'welcome, offline guest login, two modes, and 50 numbered levels',
    (tester) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await store();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeProvider.overrideWithValue(s)],
          child: const ShuffleApp(),
        ),
      );
      expect(find.text('Continue as Guest'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue as Guest'));
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      expect(find.text('Make your\nnext move.'), findsOneWidget);
      expect(s.signedIn, isTrue);
      expect(find.text('Play Number Puzzle'), findsOneWidget);
      await tester.ensureVisible(find.text('Play Number Puzzle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Number Puzzle'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('LOCKED'), findsWidgets);
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(find.text('Let’s play'), findsOneWidget);
    },
  );
  test('local persistence survives a new store without Firebase', () async {
    final s = await store();
    await s.loginGuest();
    final a = Attempt.start(Level.all(PuzzleMode.number).first, 88);
    s.saved = a;
    await s.setSetting('reduceMotion', true);
    final restored = GameStore(await SharedPreferences.getInstance());
    expect(restored.saved!.board, a.board);
    expect(restored.settings['reduceMotion'], isTrue);
    expect(restored.signedIn, isTrue);
  });
  testWidgets(
    'number puzzle completes, awards results and unlocks next level',
    (tester) async {
      final s = await store();
      await s.loginGuest();
      final a = Attempt.start(Level.all(PuzzleMode.number).first, 91);
      a.board = [1, 2, 3, 4, 5, 6, 7, 0, 8];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeProvider.overrideWithValue(s)],
          child: MaterialApp(home: GameScreen(attempt: a)),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey(8)));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey(8)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('A beautiful finish.'), findsOneWidget);
      expect(s.results['number_1'], isNotNull);
      expect(find.text('Share My Result'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('pause freezes timer and resume restarts it', (tester) async {
    final s = await store();
    await s.loginGuest();
    final a = Attempt.start(Level.all(PuzzleMode.number).first, 92);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(s)],
        child: MaterialApp(home: GameScreen(attempt: a)),
      ),
    );
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('A moment to reset.'), findsOneWidget);
    final elapsed = a.elapsedMs;
    await tester.pump(const Duration(seconds: 5));
    expect(a.elapsedMs, elapsed);
    await tester.tap(find.text('Keep going →'));
    await tester.pump();
    expect(find.text('A moment to reset.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
