import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'data/store.dart';
import 'data/progress.dart';
import 'features/puzzle_engine/engine.dart';
import 'features/game/game_screen.dart';

const orange = Color(0xffffb17a);
const violet = Color(0xffb6a2ff);
const muted = Color(0xff9295af);

class ShuffleApp extends ConsumerWidget {
  const ShuffleApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final dark = store.settings['dark'] == true;
        return MaterialApp(
          title: 'Shuffle Slide',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Manrope',
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: dark
                ? const Color(0xff111321)
                : const Color(0xfff5f3f0),
            colorScheme: ColorScheme.fromSeed(
              seedColor: orange,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            cardTheme: CardThemeData(
              color: dark ? const Color(0xff1d2032) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: const Color(0xff251a17),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                store.settings['largeText'] == true ? 1.18 : 1,
              ),
              disableAnimations: store.settings['reduceMotion'] == true,
            ),
            child: child!,
          ),
          home: store.signedIn ? const HomeScreen() : const WelcomeScreen(),
        );
      },
    );
  }
}

void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> googleLogin(BuildContext context, GameStore store) async {
  final merge = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Connect your progress'),
      content: const Text(
        'Your saved levels, best scores, and stars will be merged with this Google account. Both sets of progress are preserved. Photos stay on this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Continue & merge'),
        ),
      ],
    ),
  );
  if (merge != true) {
    return;
  }
  final error = await store.loginGoogle(reconcileExisting: true);
  if (context.mounted && error != null) {
    message(context, error);
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A LITTLE SHIFT. A BIG DISCOVERY.',
                    style: TextStyle(
                      color: muted,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 44),
                  const MiniBoard(),
                  const SizedBox(height: 38),
                  const Text(
                    'Shuffle\nSlide.',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      height: .98,
                      letterSpacing: -3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Find your flow. One tile at a time.',
                    style: TextStyle(color: muted, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '100 challenges. Your favorite photos.\nA fresh way to give your mind a little room.',
                  ),
                  const SizedBox(height: 38),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: store.busy ? null : () => store.loginGuest(),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue as Guest'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: store.busy
                          ? null
                          : () => googleLogin(context, store),
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Continue with Google'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    store.firebaseReady
                        ? 'Play offline. Connect to keep your progress across devices.'
                        : 'Offline edition · Google and cloud sync need your Firebase configuration.',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MiniBoard extends StatelessWidget {
  const MiniBoard({super.key});
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.08,
    child: SizedBox(
      width: 172,
      height: 172,
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        physics: const NeverScrollableScrollPhysics(),
        children: [1, 2, 3, 4, 0, 5, 7, 8, 6]
            .map(
              (v) => DecoratedBox(
                decoration: BoxDecoration(
                  color: v == 0
                      ? const Color(0xff25283c)
                      : v == 5
                      ? violet
                      : orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    v == 0 ? '' : '$v',
                    style: const TextStyle(
                      color: Color(0xff252032),
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: tab == 0
                  ? home(store)
                  : tab == 1
                  ? stats(store)
                  : settings(store),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Play',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_rounded),
              label: 'Statistics',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'You',
            ),
          ],
        ),
      ),
    );
  }

  Widget home(GameStore store) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    children: [
      Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xff302c45),
            foregroundColor: violet,
            child: Icon(Icons.person_outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    color: muted,
                    letterSpacing: 1.8,
                    fontSize: 10,
                  ),
                ),
                Text(
                  store.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => tab = 2),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      const SizedBox(height: 34),
      const Text(
        'Make your\nnext move.',
        style: TextStyle(
          fontSize: 43,
          height: 1.08,
          letterSpacing: -1.7,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'A little focus. A satisfying finish.',
        style: TextStyle(color: muted, fontSize: 15),
      ),
      const SizedBox(height: 26),
      Row(
        children: [
          Expanded(
            child: stat(
              '${store.totalStars}',
              'STARS EARNED',
              Icons.star_rounded,
              orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: stat(
              '${store.completed}/100',
              'LEVELS SOLVED',
              Icons.check_circle_outline,
              violet,
            ),
          ),
        ],
      ),
      if (store.saved != null && !store.saved!.finished) ...[
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.play_circle_fill, color: orange),
            title: const Text('Pick up where you left off'),
            subtitle: Text(
              '${store.saved!.level.mode.name} · Level ${store.saved!.level.id}',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => openGame(context, store.saved!),
          ),
        ),
      ],
      const SizedBox(height: 30),
      const Row(
        children: [
          Expanded(
            child: Text(
              'CHOOSE YOUR CHALLENGE',
              style: TextStyle(fontSize: 11, letterSpacing: 1.8, color: muted),
            ),
          ),
          Text('02 MODES', style: TextStyle(fontSize: 10, color: muted)),
        ],
      ),
      const SizedBox(height: 16),
      modeCard(
        PuzzleMode.number,
        'The classic,\nwith a twist.',
        'Slide the numbers into the correct order.\nBeat the clock and challenge your brain!',
        orange,
        Icons.apps_rounded,
        store,
      ),
      const SizedBox(height: 16),
      modeCard(
        PuzzleMode.photo,
        'Your memories.\nRemixed.',
        'Turn your favorite photos into puzzles.\nShuffle, slide, and restore the original picture!',
        violet,
        Icons.landscape_outlined,
        store,
      ),
      const SizedBox(height: 24),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: muted),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Made for your downtime. Works offline.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
        ],
      ),
    ],
  );
  Widget stat(String value, String label, IconData icon, Color color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 25),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    ),
  );
  Widget modeCard(
    PuzzleMode mode,
    String title,
    String description,
    Color color,
    IconData icon,
    GameStore store,
  ) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LevelScreen(mode: mode)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Text(
                  mode == PuzzleMode.number ? 'NUMBER PUZZLE' : 'PHOTO PUZZLE',
                  style: TextStyle(
                    color: color,
                    letterSpacing: 1.4,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.north_east, color: muted, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                height: 1.13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == PuzzleMode.number
                      ? 'Play Number Puzzle'
                      : 'Play Photo Puzzle',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '50 levels · ${unlockedLevel(store.results, mode) - 1} solved',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget stats(GameStore store) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Your progress.',
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text('Every little move adds up.', style: TextStyle(color: muted)),
      const SizedBox(height: 28),
      stat(
        '${store.completed}',
        'UNIQUE LEVELS COMPLETED',
        Icons.emoji_events_outlined,
        orange,
      ),
      const SizedBox(height: 12),
      stat('${store.totalStars}', 'TOTAL STARS', Icons.star_rounded, orange),
      const SizedBox(height: 12),
      stat(
        '${store.totalScore}',
        'COMBINED PERSONAL BESTS',
        Icons.bolt,
        violet,
      ),
      const SizedBox(height: 12),
      stat(
        '${store.attempts.length}',
        'COMPLETED ATTEMPTS',
        Icons.check_circle_outline,
        violet,
      ),
      const SizedBox(height: 24),
      for (final mode in PuzzleMode.values)
        Card(
          child: ListTile(
            title: Text('${mode.name == 'number' ? 'Number' : 'Photo'} Puzzle'),
            subtitle: Text(
              '${store.results.keys.where((k) => k.startsWith(mode.name)).length}/50 levels complete',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LevelScreen(mode: mode)),
            ),
          ),
        ),
      const SizedBox(height: 16),
      if (store.totalStars >= 3)
        const ListTile(
          leading: Icon(Icons.workspace_premium, color: orange),
          title: Text('First constellation'),
          subtitle: Text('Earned at least 3 stars'),
        ),
      if (store.completed >= 10)
        const ListTile(
          leading: Icon(Icons.workspace_premium, color: violet),
          title: Text('Finding your flow'),
          subtitle: Text('Completed 10 unique levels'),
        ),
    ],
  );
  Widget settings(GameStore store) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Your space.',
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                store.user?.isAnonymous == false
                    ? 'Connected with Google'
                    : 'Guest profile · progress saved locally',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              if (store.user?.isAnonymous != false)
                FilledButton.icon(
                  onPressed: store.busy
                      ? null
                      : () => googleLogin(context, store),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Connect with Google'),
                ),
              Text(
                store.configError ?? store.syncError ?? 'Cloud sync available',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              if (store.firebaseReady)
                TextButton.icon(
                  onPressed: () => store.sync(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync progress'),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      for (final item in [
        ('dark', 'Dark theme', Icons.dark_mode_outlined),
        ('sound', 'Move sounds', Icons.volume_up_outlined),
        ('haptic', 'Haptic feedback', Icons.vibration),
        ('reduceMotion', 'Reduced motion', Icons.animation),
        ('largeText', 'Larger text', Icons.text_fields),
      ])
        SwitchListTile(
          secondary: Icon(item.$3),
          title: Text(item.$2),
          value: store.settings[item.$1] == true,
          onChanged: (v) => store.setSetting(item.$1, v),
        ),
      ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: const Text('Manage local photos'),
        subtitle: const Text('Private. Never uploaded to cloud sync.'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhotoLibraryScreen()),
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Scores and levels can sync across devices. Imported photos stay on this device and do not transfer automatically.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ),
      OutlinedButton(
        onPressed: () => store.signOut(),
        child: const Text('Sign out (keep local progress)'),
      ),
      TextButton(
        onPressed: () async {
          final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Delete account and progress?'),
              content: const Text(
                'This permanently removes your cloud profile, local progress, and imported puzzle copies. Your original gallery photos are untouched.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (yes == true) {
            final error = await store.deleteAccount();
            if (mounted && error != null) {
              message(context, error);
            }
          }
        },
        child: const Text(
          'Delete account & progress',
          style: TextStyle(color: Colors.redAccent),
        ),
      ),
    ],
  );
}

Future<void> openGame(BuildContext context, Attempt attempt) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GameScreen(attempt: attempt)),
  );
}

class LevelScreen extends ConsumerWidget {
  final PuzzleMode mode;
  const LevelScreen({super.key, required this.mode});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            mode == PuzzleMode.number ? 'Number Puzzle' : 'Photo Puzzle',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Find your next\nlittle victory.',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '50 levels · ${store.results.keys.where((k) => k.startsWith(mode.name)).length} completed',
                    style: const TextStyle(color: muted),
                  ),
                  if (mode == PuzzleMode.photo) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: violet,
                        ),
                        title: const Text('Choose your puzzle photo'),
                        subtitle: Text(
                          store.selectedPhoto == null
                              ? 'Mountain sunset sample selected'
                              : 'Your private photo selected',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PhotoLibraryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  for (final stage in [
                    (1, 10, '01  BEGINNER', '3 × 3 · Find your rhythm'),
                    (11, 25, '02  INTERMEDIATE', '4 × 4 · A little more focus'),
                    (26, 40, '03  ADVANCED', '5 × 5 · Think a few moves ahead'),
                    (41, 50, '04  EXPERT', '6 × 6 · The ultimate shuffle'),
                  ]) ...[
                    const SizedBox(height: 28),
                    Text(
                      stage.$3,
                      style: const TextStyle(
                        color: orange,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stage.$4,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, box) => Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(stage.$2 - stage.$1 + 1, (i) {
                          final id = i + stage.$1,
                              record = store.results[resultKey(mode, id)],
                              unlocked =
                                  id <= unlockedLevel(store.results, mode);
                          return SizedBox(
                            width: (box.maxWidth - 40) / 5,
                            height: 76,
                            child: Material(
                              color: record != null
                                  ? orange.withValues(alpha: .14)
                                  : Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(15),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: !unlocked
                                    ? null
                                    : () async {
                                        final level = Level.all(mode)[id - 1];
                                        final proceed = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: Text(
                                              'Level $id · ${level.difficulty}',
                                            ),
                                            content: Text(
                                              '${level.size} × ${level.size} board\n${level.seconds} seconds · ${level.hints} hints\n\nTap or swipe tiles toward the gap. Tiles in the same row or column slide together.\n\n${mode == PuzzleMode.photo ? 'Reference previews: ${level.previews == 999 ? 'unlimited' : level.previews}. Timer continues; regular previews cost 50 points.' : 'Hints cost 150 points. Undo costs 20 points.'}',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text('Back'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Let’s play'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (proceed == true &&
                                            context.mounted) {
                                          await openGame(
                                            context,
                                            Attempt.start(
                                              level,
                                              DateTime.now()
                                                  .microsecondsSinceEpoch,
                                            ),
                                          );
                                        }
                                      },
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      unlocked
                                          ? Text(
                                              '$id',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.lock_outline,
                                              size: 19,
                                              color: muted,
                                            ),
                                      const SizedBox(height: 4),
                                      if (record != null)
                                        Text(
                                          '★' * (record['stars'] as int),
                                          style: const TextStyle(
                                            color: orange,
                                            fontSize: 10,
                                          ),
                                        )
                                      else
                                        Text(
                                          unlocked ? 'PLAY' : 'LOCKED',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 7,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhotoLibraryScreen extends ConsumerStatefulWidget {
  const PhotoLibraryScreen({super.key});
  @override
  ConsumerState<PhotoLibraryScreen> createState() => _PhotoLibraryScreenState();
}

class _PhotoLibraryScreenState extends ConsumerState<PhotoLibraryScreen> {
  bool importing = false;
  Future<void> pick() async {
    if (importing) {
      return;
    }
    setState(() => importing = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (image == null) {
        return;
      }
      if (await File(image.path).length() > 30 * 1024 * 1024) {
        throw const FormatException(
          'Image is too large. Choose a smaller photo.',
        );
      }
      final crop = await ImageCropper().cropImage(
        sourcePath: image.path,
        maxWidth: 1200,
        maxHeight: 1200,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Frame your puzzle',
            toolbarColor: const Color(0xff1d2032),
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Frame your puzzle',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (crop != null) {
        await ref.read(storeProvider).importPhoto(crop.path);
      }
    } catch (e) {
      if (mounted) {
        message(context, 'Photo could not be imported: $e');
      }
    } finally {
      if (mounted) {
        setState(() => importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Your photo collection')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Make it personal.',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose a photo, frame it as a square, then bring it back together. Your original stays untouched.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: importing ? null : pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                importing ? 'Opening photo…' : 'Choose Photo from Gallery',
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Directory>(
              future: getApplicationDocumentsDirectory(),
              builder: (context, snapshot) => snapshot.hasData
                  ? photoCard(store, '${snapshot.data!.path}/sample.png', true)
                  : const LinearProgressIndicator(),
            ),
            for (final path in store.photos) photoCard(store, path, false),
            const SizedBox(height: 20),
            const Text(
              'Only scores and levels sync. Photos stay private on this device. You can share a result without including your photo.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget photoCard(GameStore store, String path, bool sample) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: Image.file(
                File(path),
                cacheWidth: 900,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Text('Photo is no longer available. Choose another.'),
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(sample ? 'Mountain sunset' : 'Your photo'),
            subtitle: Text(
              sample ? 'Built-in sample' : 'Stored only on this device',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!sample)
                  IconButton(
                    onPressed: () => store.removePhoto(path),
                    icon: const Icon(Icons.delete_outline),
                  ),
                TextButton(
                  onPressed: () async {
                    await store.selectPhoto(sample ? null : path);
                    if (mounted) {
                      message(context, 'Puzzle photo selected');
                    }
                  },
                  child: Text(
                    (sample && store.selectedPhoto == null) ||
                            store.selectedPhoto == path
                        ? 'Selected ✓'
                        : 'Use photo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
