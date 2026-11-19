import 'dart:async';
import 'dart:io';
import 'dart:math';

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
  final double size;
  const MiniBoard({super.key, this.size = 172});
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.08,
    child: SizedBox(
      width: size,
      height: size,
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: size / 24,
        crossAxisSpacing: size / 24,
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
                  borderRadius: BorderRadius.circular(size / 14),
                ),
                child: Center(
                  child: Text(
                    v == 0 ? '' : '$v',
                    style: TextStyle(
                      color: Color(0xff252032),
                      fontSize: size / 6.4,
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

class PuzzlePreview extends StatefulWidget {
  final PuzzleMode mode;
  final Color accent;
  const PuzzlePreview({super.key, required this.mode, required this.accent});
  @override
  State<PuzzlePreview> createState() => _PuzzlePreviewState();
}

class _PuzzlePreviewState extends State<PuzzlePreview> {
  late final Timer timer;
  final tiles = [1, 2, 3, 4, 5, 6, 7, 0, 8];
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() {
        final empty = tiles.indexOf(0);
        final next = empty == 7 ? 8 : 7;
        tiles[empty] = tiles[next];
        tiles[next] = 0;
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = min(132.0, box.maxHeight - 25);
      const spacing = 5.0;
      final tileSide = (side - spacing * 2) / 3;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accent.withValues(alpha: .30),
              const Color(0xff29283f),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 16,
              top: 14,
              child: Text(
                widget.mode == PuzzleMode.number
                    ? 'CLASSIC MODE'
                    : 'YOUR PHOTO, YOUR PUZZLE',
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  for (final tile in tiles.where((tile) => tile != 0))
                    AnimatedPositioned(
                      key: ValueKey(tile),
                      duration: const Duration(milliseconds: 480),
                      curve: Curves.easeInOutCubic,
                      left: tiles.indexOf(tile) % 3 * (tileSide + spacing),
                      top: tiles.indexOf(tile) ~/ 3 * (tileSide + spacing),
                      width: tileSide,
                      height: tileSide,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: widget.mode == PuzzleMode.number
                              ? (tile == 5 ? violet : orange)
                              : null,
                          gradient: widget.mode == PuzzleMode.photo
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    [
                                      const Color(0xfff3ba78),
                                      const Color(0xffbf899f),
                                      const Color(0xff7483ad),
                                      const Color(0xff3b6680),
                                    ][tile % 4],
                                    [
                                      const Color(0xff8d758d),
                                      const Color(0xff6e9e9c),
                                      const Color(0xffdbad75),
                                      const Color(0xff333e67),
                                    ][(tile + 1) % 4],
                                  ],
                                )
                              : null,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: widget.mode == PuzzleMode.number
                            ? Center(
                                child: Text(
                                  '$tile',
                                  style: const TextStyle(
                                    color: Color(0xff35253a),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 21,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  [
                                    Icons.landscape_rounded,
                                    Icons.wb_sunny_rounded,
                                    Icons.water_rounded,
                                  ][tile % 3],
                                  color: Colors.white.withValues(alpha: .78),
                                  size: 19,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class WeeklyLeaderboard extends StatelessWidget {
  final GameStore store;
  const WeeklyLeaderboard({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xff22253a),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: orange.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WEEKLY CHAMPIONS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Best puzzle score  ·  ${store.leaderboardWeek}',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.military_tech_rounded, color: orange, size: 28),
          ],
        ),
        const SizedBox(height: 12),
        if (!store.firebaseReady)
          const Text(
            'Play is ready offline. Online weekly rankings become available when cloud sync is connected.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          )
        else
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: store.weeklyLeaderboard(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (snapshot.hasError) {
                return const Text(
                  'Leaderboard is temporarily unavailable.',
                  style: TextStyle(color: muted, fontSize: 11),
                );
              }
              if (rows.isEmpty) {
                return Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading this week’s scores…'
                      : 'No scores yet. Finish a puzzle to claim the first trophy!',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < min(rows.length, 5); i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 25,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: i == 0 ? orange : muted,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: i == 0
                                ? orange.withValues(alpha: .2)
                                : const Color(0xff30334a),
                            child: Icon(
                              i == 0
                                  ? Icons.emoji_events_rounded
                                  : Icons.person_rounded,
                              size: 15,
                              color: i == 0 ? orange : muted,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              rows[i]['displayName'] as String? ?? 'Player',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${rows[i]['score'] ?? 0}',
                            style: const TextStyle(
                              color: orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
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
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xff45325f), Color(0xff26253d), Color(0xff202338)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'READY, PLAYER?',
                    style: TextStyle(
                      color: orange,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pick your\nnext puzzle.',
                    style: TextStyle(
                      fontSize: 29,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${store.totalStars} stars  ·  ${store.completed} levels cleared',
                    style: const TextStyle(
                      color: Color(0xffc3c0d1),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const MiniBoard(size: 104),
          ],
        ),
      ),
      const SizedBox(height: 24),
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
      const SizedBox(height: 24),
      const Row(
        children: [
          Expanded(
            child: Text(
              'CHOOSE YOUR GAME',
              style: TextStyle(fontSize: 11, letterSpacing: 1.8, color: muted),
            ),
          ),
          Text('TAP TO PLAY', style: TextStyle(fontSize: 10, color: muted)),
        ],
      ),
      const SizedBox(height: 16),
      modeCard(
        PuzzleMode.number,
        'Number Puzzle',
        'Put every tile in its place. Can you beat the clock?',
        orange,
        Icons.apps_rounded,
        store,
      ),
      const SizedBox(height: 16),
      modeCard(
        PuzzleMode.photo,
        'Photo Puzzle',
        'Mix up a favorite photo, then bring the picture back.',
        violet,
        Icons.landscape_outlined,
        store,
      ),
      const SizedBox(height: 22),
      WeeklyLeaderboard(store: store),
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
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LevelScreen(mode: mode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 174,
            child: PuzzlePreview(mode: mode, accent: color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${unlockedLevel(store.results, mode) - 1} levels cleared  ·  50 levels',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xff251a17),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
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
