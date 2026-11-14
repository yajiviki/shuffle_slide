import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../puzzle_engine/engine.dart';
import '../../../data/store.dart';
import '../../../main.dart';
import '../../../app.dart';

class GameScreen extends ConsumerStatefulWidget {
  final Attempt attempt;
  const GameScreen({super.key, required this.attempt});
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late Attempt a;
  late GameStore store;
  Timer? ticker;
  final Stopwatch clock = Stopwatch();
  int baseMs = 0, lastSave = -1;
  bool paused = false,
      moving = false,
      searching = false,
      resultOpen = false,
      best = false;
  int? hinted;
  String? photoPath;
  ImageProvider? photo;
  @override
  void initState() {
    super.initState();
    a = widget.attempt;
    store = ref.read(storeProvider);
    WidgetsBinding.instance.addObserver(this);
    baseMs = a.elapsedMs;
    clock.start();
    store.saved = a;
    ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    unawaited(store.persist());
    if (a.level.mode == PuzzleMode.photo) {
      unawaited(loadPhoto());
    }
  }

  Future<void> loadPhoto() async {
    final directory = await getApplicationDocumentsDirectory();
    final path =
        a.photoPath ?? store.selectedPhoto ?? '${directory.path}/sample.png';
    if (!await File(path).exists()) {
      if (mounted) {
        message(
          context,
          'The selected photo is missing. Using the built-in sample.',
        );
      }
      photoPath = '${directory.path}/sample.png';
    } else {
      photoPath = path;
    }
    a.photoPath = photoPath;
    if (mounted) {
      setState(
        () => photo = ResizeImage(FileImage(File(photoPath!)), width: 1200),
      );
    }
  }

  void tick() {
    if (!mounted || paused || a.finished || resultOpen) {
      return;
    }
    setState(() => a.elapsedMs = baseMs + clock.elapsedMilliseconds);
    if (a.remaining == 0) {
      stopClock();
      unawaited(showResult(false));
    } else if (a.elapsedMs ~/ 5000 != lastSave) {
      lastSave = a.elapsedMs ~/ 5000;
      unawaited(store.persist());
    }
  }

  void stopClock() {
    a.elapsedMs = baseMs + clock.elapsedMilliseconds;
    baseMs = a.elapsedMs;
    clock
      ..stop()
      ..reset();
  }

  void resumeClock() {
    if (!a.finished && a.remaining > 0) {
      clock.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (!paused && !resultOpen) {
        stopClock();
        setState(() => paused = true);
      }
      unawaited(store.persist());
    } else {
      unawaited(store.sync());
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> makeMove(int index) async {
    if (moving || paused || resultOpen || searching) {
      return;
    }
    a.elapsedMs = baseMs + clock.elapsedMilliseconds;
    if (a.remaining <= 0) {
      return;
    }
    if (!a.move(index)) {
      return;
    }
    if (store.settings['haptic'] == true) {
      unawaited(HapticFeedback.selectionClick());
    }
    if (store.settings['sound'] == true) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    setState(() {
      moving = true;
      hinted = null;
    });
    await Future<void>.delayed(
      Duration(milliseconds: store.settings['reduceMotion'] == true ? 0 : 240),
    );
    if (!mounted) {
      return;
    }
    setState(() => moving = false);
    await store.persist();
    if (a.finished) {
      stopClock();
      best = await store.complete(a);
      if (mounted) {
        await showResult(true);
      }
    }
  }

  Future<void> hint() async {
    if (searching ||
        moving ||
        paused ||
        a.hintsUsed >= a.level.hints ||
        a.finished) {
      return;
    }
    final fallback = a.hint();
    if (fallback == null) {
      return;
    }
    setState(() => searching = true);
    final index = await compute(searchHint, {
      'board': a.board,
      'size': a.level.size,
    });
    if (!mounted) {
      return;
    }
    setState(() {
      searching = false;
      hinted = index ?? fallback;
    });
    await store.persist();
  }

  Future<void> undo() async {
    if (moving || paused || searching) {
      return;
    }
    if (a.undo()) {
      setState(() {
        hinted = null;
        moving = true;
      });
      await Future<void>.delayed(
        Duration(
          milliseconds: store.settings['reduceMotion'] == true ? 0 : 130,
        ),
      );
      if (mounted) {
        setState(() => moving = false);
      }
      await store.persist();
    }
  }

  Future<void> pause() async {
    if (resultOpen || a.finished) {
      return;
    }
    stopClock();
    setState(() => paused = true);
    await store.persist();
  }

  Future<void> leave() async {
    stopClock();
    await store.persist();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> preview() async {
    if (photo == null || paused || resultOpen) {
      return;
    }
    if (a.previewsUsed >= a.level.previews) {
      message(context, 'No reference previews left in this attempt.');
      return;
    }
    a.previewsUsed++;
    if (a.level.id > 3) {
      a.penalties += 50;
    }
    await store.persist();
    if (!mounted) {
      return;
    }
    final route = DialogRoute<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Your reference'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image(image: photo!, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            Text(
              a.level.id <= 3 ? 'Timer continues · tutorial preview is free' : 'Timer continues · 50 point penalty\nCloses automatically after 3 seconds',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Back to puzzle'),
          ),
        ],
      ),
    );
    Timer? closer;
    if (a.level.id > 3) {
      closer = Timer(const Duration(seconds: 3), () {
        if (route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    }
    await Navigator.of(context).push(route);
    closer?.cancel();
  }

  Future<void> restart() async {
    ticker?.cancel();
    store.saved = null;
    await store.persist();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            attempt: Attempt.start(
              a.level,
              DateTime.now().microsecondsSinceEpoch,
            ),
          ),
        ),
      );
    }
  }

  Future<void> showResult(bool success) async {
    if (resultOpen || !mounted) {
      return;
    }
    setState(() => resultOpen = true);
    if (!success) {
      store.saved = null;
      await store.persist();
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(success ? 'A beautiful finish.' : 'Take a breath.'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (success)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: .5, end: 1),
                    duration: Duration(
                      milliseconds: store.settings['reduceMotion'] == true
                          ? 0
                          : 600,
                    ),
                    builder: (_, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Text(
                      '★' * a.stars + '☆' * (3 - a.stars),
                      style: const TextStyle(fontSize: 42, color: orange),
                    ),
                  ),
                Text(
                  '${a.level.mode == PuzzleMode.number ? 'Number' : 'Photo'} Puzzle · Level ${a.level.id}',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 16),
                Text(
                  success ? '${a.finalScore}' : 'Time’s up',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (success && best)
                  const Text(
                    'NEW PERSONAL BEST',
                    style: TextStyle(
                      color: violet,
                      fontSize: 11,
                      letterSpacing: 1.3,
                    ),
                  ),
                if (success && photo != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image(image: photo!, fit: BoxFit.cover),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '${a.moves} moves  ·  ${formatTime(a.elapsedMs ~/ 1000)} elapsed',
                ),
                const SizedBox(height: 12),
                if (success) ...[
                  breakdown('Correct placements', a.placement),
                  breakdown('Combo rewards', a.comboReward),
                  breakdown('Time bonus', a.timeBonus),
                  breakdown('Move efficiency', a.moveBonus),
                  breakdown('Penalties', -a.penalties),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => shareResult(),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share My Result'),
                  ),
                ] else
                  const Text(
                    'Every attempt teaches you a little more. Try a fresh shuffle.',
                    style: TextStyle(color: muted),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
              child: const Text('Level menu'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                if (success && a.level.id < 50) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        attempt: Attempt.start(
                          Level.all(a.level.mode)[a.level.id],
                          DateTime.now().microsecondsSinceEpoch,
                        ),
                      ),
                    ),
                  );
                } else {
                  unawaited(restart());
                }
              },
              child: Text(
                success && a.level.id < 50 ? 'Next level →' : 'Try again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget breakdown(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Text('$value', style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
  Future<void> shareResult() async {
    bool include = false;
    if (photo != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Share your achievement'),
          content: const Text(
            'The result card is private by default. Would you like to include your puzzle photo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Result only'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Include photo'),
            ),
          ],
        ),
      );
      if (choice == null) {
        return;
      }
      include = choice;
    }
    try {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 1080, 900),
          const Radius.circular(40),
        ),
        Paint()..color = const Color(0xff171a2b),
      );
      void text(String value, double top, double size, Color color) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 960);
        painter.paint(canvas, Offset(60, top));
      }

      text('SHUFFLE SLIDE', 60, 28, violet);
      text(
        '${a.level.mode == PuzzleMode.photo ? 'Photo' : 'Number'} Puzzle',
        125,
        60,
        Colors.white,
      );
      text('Level ${a.level.id} complete', 215, 40, Colors.white);
      text('${a.finalScore} POINTS', 300, 72, orange);
      text('${a.stars}/3 STARS', 410, 34, orange);
      text(
        '${a.moves} moves  •  ${formatTime(a.elapsedMs ~/ 1000)}',
        490,
        32,
        Colors.white,
      );
      text('Can you beat my score?', 700, 44, Colors.white);
      text('One tile at a time.', 785, 24, muted);
      if (include && photoPath != null) {
        final codec = await ui.instantiateImageCodec(
          await File(photoPath!).readAsBytes(),
          targetWidth: 230,
        );
        final frame = await codec.getNextFrame();
        canvas.drawImageRect(
          frame.image,
          Rect.fromLTWH(
            0,
            0,
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          ),
          const Rect.fromLTWH(790, 420, 230, 230),
          Paint(),
        );
        // Release after rasterization below.
        final picture = recorder.endRecording();
        final output = await picture.toImage(1080, 900);
        frame.image.dispose();
        codec.dispose();
        picture.dispose();
        await writeAndShare(output);
        output.dispose();
      } else {
        final picture = recorder.endRecording();
        final image = await picture.toImage(1080, 900);
        picture.dispose();
        await writeAndShare(image);
        image.dispose();
      }
    } catch (e) {
      if (mounted) {
        message(context, 'Sharing unavailable: $e');
      }
    }
  }

  Future<void> writeAndShare(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png),
        dir = await getTemporaryDirectory();
    final path = '${dir.path}/shuffle_result.png';
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    if (!mounted) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text:
            'I completed Level ${a.level.id} in Shuffle Slide – ${a.level.mode == PuzzleMode.photo ? 'Photo' : 'Number'} Puzzle! Score: ${a.finalScore} · Stars: ${a.stars}/3 · Moves: ${a.moves} · Time: ${formatTime(a.elapsedMs ~/ 1000)}. Can you beat my score?',
        sharePositionOrigin: box == null
            ? const Rect.fromLTWH(0, 0, 1, 1)
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !resultOpen) {
        unawaited(pause());
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: pause,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          '${a.level.mode == PuzzleMode.number ? 'Number' : 'Photo'} Puzzle',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(onPressed: pause, icon: const Icon(Icons.pause_rounded)),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: violet.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LEVEL ${a.level.id.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: violet,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${a.level.difficulty}  ·  ${a.level.size} × ${a.level.size}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'One tile closer.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Slide into place. Find your flow.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: metric(
                            'TIME LEFT',
                            formatTime(a.remaining),
                            a.remaining < 10 ? Colors.redAccent : orange,
                          ),
                        ),
                        Expanded(child: metric('MOVES', '${a.moves}', violet)),
                        Expanded(
                          child: metric('SCORE', '${a.score}', Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: a.remaining / a.level.seconds,
                        backgroundColor: const Color(0xff292c40),
                        color: a.remaining < 10 ? Colors.redAccent : orange,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Semantics(
                      label:
                          'Sliding puzzle, ${a.level.size} by ${a.level.size}. Tap a tile in the same row or column as the empty space.',
                      child: board(),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        tool(
                          Icons.lightbulb_outline,
                          searching ? 'Thinking…' : 'Hint',
                          '${a.level.hints - a.hintsUsed} left · −150',
                          hint,
                        ),
                        tool(
                          Icons.undo_rounded,
                          'Undo',
                          '${3 - a.undos} left · −20',
                          undo,
                        ),
                        if (a.level.mode == PuzzleMode.photo)
                          tool(
                            Icons.image_outlined,
                            'Reference',
                            a.level.id <= 3
                                ? 'Free · timer runs'
                                : '−50 · timer runs',
                            preview,
                          )
                        else
                          tool(
                            Icons.pause_circle_outline,
                            'Pause',
                            'Take a moment',
                            pause,
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        hinted == null
                            ? 'Tap a tile or swipe toward the empty space'
                            : 'The outlined tile is your next suggested move',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                    if (a.combo > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Text(
                            '${min(1 + .1 * a.combo, 3).toStringAsFixed(1)}× COMBO',
                            style: const TextStyle(
                              color: orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (paused)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor
                      .withValues(alpha: .97),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pause_circle_outline,
                            color: orange,
                            size: 64,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'A moment to reset.',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your timer is paused. Your puzzle is saved.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 30),
                          FilledButton(
                            onPressed: () {
                              setState(() => paused = false);
                              resumeClock();
                            },
                            child: const Text('Keep going →'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: restart,
                            child: const Text('Restart with a new shuffle'),
                          ),
                          TextButton(
                            onPressed: leave,
                            child: const Text('Save & leave'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget metric(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 9, color: muted, letterSpacing: 1.4),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: color == Colors.white
              ? Theme.of(context).colorScheme.onSurface
              : color,
        ),
      ),
    ],
  );
  Widget tool(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => Expanded(
    child: TextButton(
      onPressed: moving || searching ? null : action,
      child: Column(
        children: [
          if (icon == Icons.image_outlined && photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image(
                image: photo!,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            )
          else
            Icon(icon, color: violet, size: 25),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 9)),
        ],
      ),
    ),
  );
  Widget board() => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = a.level.size,
            full = constraints.maxWidth,
            gap = size >= 5 ? 5.0 : 8.0;
        final step = full / size, side = step - gap;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff0b0d18),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .2),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              for (var tile = 1; tile < size * size; tile++)
                tileWidget(tile, step, side, gap, size),
              Positioned(
                left: a.board.indexOf(0) % size * step + gap / 2,
                top: a.board.indexOf(0) ~/ size * step + gap / 2,
                width: side,
                height: side,
                child: IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.open_with,
                      size: 18,
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget tileWidget(int tile, double step, double side, double gap, int size) {
    final index = a.board.indexOf(tile), correct = index == tile - 1;
    return AnimatedPositioned(
      key: ValueKey(tile),
      duration: Duration(
        milliseconds: store.settings['reduceMotion'] == true ? 0 : 220,
      ),
      curve: Curves.easeInOutCubic,
      left: index % size * step + gap / 2,
      top: index ~/ size * step + gap / 2,
      width: side,
      height: side,
      child: Semantics(
        button: true,
        label: 'Tile $tile${correct ? ', correct position' : ''}',
        child: GestureDetector(
          onTap: () => makeMove(index),
          onPanEnd: (details) {
            final velocity = details.velocity.pixelsPerSecond,
                empty = a.board.indexOf(0);
            final dx = empty % size - index % size,
                dy = empty ~/ size - index ~/ size;
            if ((dx != 0 && dx * velocity.dx > 0) ||
                (dy != 0 && dy * velocity.dy > 0)) {
              unawaited(makeMove(index));
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: correct ? const Color(0xffffc69b) : orange,
              borderRadius: BorderRadius.circular(size >= 5 ? 9 : 14),
              border: hinted == index
                  ? Border.all(color: violet, width: 4)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .15),
                  offset: const Offset(0, 3),
                  blurRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size >= 5 ? 8 : 13),
              child: a.level.mode == PuzzleMode.photo && photo != null
                  ? Stack(
                      children: [
                        Positioned(
                          left: -((tile - 1) % size) * side,
                          top: -((tile - 1) ~/ size) * side,
                          width: side * size,
                          height: side * size,
                          child: Image(
                            image: photo!,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$tile',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        '$tile',
                        style: TextStyle(
                          fontSize: size >= 5 ? 25 : 38,
                          color: const Color(0xff352322),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatTime(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
