import 'dart:math';

enum PuzzleMode { number, photo }

class Level {
  final PuzzleMode mode;
  final int id,
      size,
      scramble,
      seconds,
      parMoves,
      parSeconds,
      threshold,
      hints,
      previews;
  const Level(
    this.mode,
    this.id,
    this.size,
    this.scramble,
    this.seconds,
    this.parMoves,
    this.parSeconds,
    this.threshold,
    this.hints,
    this.previews,
  );
  String get difficulty => size == 3
      ? 'Beginner'
      : size == 4
      ? 'Intermediate'
      : size == 5
      ? 'Advanced'
      : 'Expert';
  static List<Level> all(PuzzleMode mode) => List.generate(50, (i) {
    final id = i + 1;
    final stage = id <= 10
        ? [1, 10, 3, 10, 50, 180, 100]
        : id <= 25
        ? [11, 25, 4, 50, 140, 260, 160]
        : id <= 40
        ? [26, 40, 5, 100, 280, 390, 240]
        : [41, 50, 6, 200, 450, 480, 300];
    final t = (id - stage[0]) / (stage[1] - stage[0]);
    final scramble = (stage[3] + (stage[4] - stage[3]) * t).round();
    final seconds = (stage[5] + (stage[6] - stage[5]) * t).round();
    return Level(
      mode,
      id,
      stage[2],
      scramble,
      seconds,
      scramble,
      (seconds * .7).round(),
      (seconds * 5 + stage[2] * stage[2] * 70),
      3,
      id <= 3
          ? 999
          : stage[2] == 6
          ? 1
          : 3,
    );
  });
}

List<int> solvedBoard(int size) =>
    List.generate(size * size, (i) => (i + 1) % (size * size));
bool isSolved(List<int> board) => List.generate(
  board.length,
  (i) => (i + 1) % board.length,
).asMap().entries.every((e) => board[e.key] == e.value);
List<int> neighbors(List<int> board, int size) {
  final gap = board.indexOf(0), row = gap ~/ size, col = gap % size;
  return [
    if (row > 0) gap - size,
    if (row < size - 1) gap + size,
    if (col > 0) gap - 1,
    if (col < size - 1) gap + 1,
  ];
}

class MoveRecord {
  final List<int> board, trail;
  MoveRecord(this.board, this.trail);
  Map<String, dynamic> toJson() => {'board': board, 'trail': trail};
}

class Attempt {
  final Level level;
  final int seed;
  List<int> board, trail;
  final List<MoveRecord> history;
  final Set<int> awarded;
  int moves,
      placement,
      comboReward,
      penalties,
      hintsUsed,
      undos,
      previewsUsed,
      elapsedMs;
  int combo = 0, lastPlacementMs = -100000;
  bool finished = false;
  String? photoPath;
  Attempt._(
    this.level,
    this.seed,
    this.board,
    this.trail,
    this.history,
    this.awarded,
    this.moves,
    this.placement,
    this.comboReward,
    this.penalties,
    this.hintsUsed,
    this.undos,
    this.previewsUsed,
    this.elapsedMs,
  );
  factory Attempt.start(Level level, int seed) {
    final board = solvedBoard(level.size),
        trail = <int>[],
        random = Random(seed);
    int previousGap = -1;
    for (var i = 0; i < level.scramble; i++) {
      final gap = board.indexOf(0);
      final options = neighbors(
        board,
        level.size,
      ).where((i) => i != previousGap).toList();
      final target = options[random.nextInt(options.length)];
      final tile = board[target];
      board[gap] = tile;
      board[target] = 0;
      trail.add(tile);
      previousGap = gap;
    }
    if (isSolved(board)) {
      final target = neighbors(board, level.size).first, gap = board.indexOf(0);
      trail.add(board[target]);
      board[gap] = board[target];
      board[target] = 0;
    }
    return Attempt._(level, seed, board, trail, [], {}, 0, 0, 0, 0, 0, 0, 0, 0);
  }
  int get remaining => max(0, level.seconds - elapsedMs ~/ 1000);
  int get score => max(0, placement + comboReward - penalties);
  int get timeBonus => remaining * 10;
  int get moveBonus => max(0, level.parMoves - moves) * 50;
  int get finalScore =>
      max(0, placement + comboReward + timeBonus + moveBonus - penalties);
  int get stars => finalScore < level.threshold
      ? 1
      : elapsedMs <= level.parSeconds * 1000 && hintsUsed == 0
      ? 3
      : 2;
  bool move(int index, {bool record = true}) {
    if (finished ||
        remaining == 0 ||
        index < 0 ||
        index >= board.length ||
        board[index] == 0) {
      return false;
    }
    final gap = board.indexOf(0), size = level.size;
    if (index ~/ size != gap ~/ size && index % size != gap % size) {
      return false;
    }
    if (record) {
      history.add(MoveRecord(List.of(board), List.of(trail)));
    }
    final step = index ~/ size == gap ~/ size
        ? (index > gap ? 1 : -1)
        : (index > gap ? size : -size);
    for (int pos = gap; pos != index; pos += step) {
      final tile = board[pos + step];
      board[pos] = tile;
      board[pos + step] = 0;
      moves++;
      if (trail.isNotEmpty && trail.last == tile) {
        trail.removeLast();
      } else {
        trail.add(tile);
      }
      if (pos == tile - 1 && !awarded.contains(tile)) {
        combo = elapsedMs - lastPlacementMs <= 2000 ? combo + 1 : 0;
        final multiplier = min(1 + .1 * combo, 3.0);
        placement += 100;
        comboReward += (100 * (multiplier - 1)).round();
        awarded.add(tile);
        lastPlacementMs = elapsedMs;
      } else if (pos != tile - 1) {
        combo = 0;
        lastPlacementMs = -100000;
      }
    }
    finished = isSolved(board);
    return true;
  }

  bool undo() {
    if (finished || remaining == 0 || history.isEmpty || undos >= 3) {
      return false;
    }
    final before = history.removeLast();
    board = before.board;
    trail = before.trail;
    // Placement awards remain consumed: undo cannot farm score or erase hints.
    undos++;
    penalties += 20;
    combo = 0;
    lastPlacementMs = -100000;
    return true;
  }

  int? hint() {
    if (finished ||
        remaining == 0 ||
        hintsUsed >= level.hints ||
        trail.isEmpty) {
      return null;
    }
    hintsUsed++;
    penalties += 150;
    combo = 0;
    return board.indexOf(trail.last);
  }

  Map<String, dynamic> toJson() => {
    'mode': level.mode.name,
    'level': level.id,
    'seed': seed,
    'board': board,
    'trail': trail,
    'history': history.map((e) => e.toJson()).toList(),
    'awarded': awarded.toList(),
    'moves': moves,
    'placement': placement,
    'comboReward': comboReward,
    'penalties': penalties,
    'hintsUsed': hintsUsed,
    'undos': undos,
    'previewsUsed': previewsUsed,
    'elapsedMs': elapsedMs,
    'finished': finished,
    'photoPath': photoPath,
  };
  factory Attempt.fromJson(Map<String, dynamic> json) {
    final mode = PuzzleMode.values.byName(json['mode']);
    final level = Level.all(mode)[(json['level'] as int) - 1];
    final attempt = Attempt._(
      level,
      json['seed'],
      List<int>.from(json['board']),
      List<int>.from(json['trail']),
      (json['history'] as List)
          .map(
            (e) => MoveRecord(
              List<int>.from(e['board']),
              List<int>.from(e['trail']),
            ),
          )
          .toList(),
      Set<int>.from(json['awarded']),
      json['moves'],
      json['placement'],
      json['comboReward'],
      json['penalties'],
      json['hintsUsed'],
      json['undos'],
      json['previewsUsed'],
      json['elapsedMs'],
    );
    attempt.finished = json['finished'] == true;
    attempt.photoPath = json['photoPath'];
    return attempt;
  }
}

/// Bounded best-first search for small boards. Caller runs this in an isolate.
/// Returns a legal improving move, or null so the reversible path can be used.
int? searchHint(Map<String, dynamic> input) {
  final start = List<int>.from(input['board']);
  final n = input['size'] as int;
  int distance(List<int> b) {
    var sum = 0;
    for (var i = 0; i < b.length; i++) {
      final v = b[i];
      if (v != 0) {
        sum += ((v - 1) ~/ n - i ~/ n).abs() + ((v - 1) % n - i % n).abs();
      }
    }
    return sum;
  }

  if (n > 3) {
    return null;
  }
  final queue = <({List<int> b, int first, int depth, int h})>[
    (b: start, first: -1, depth: 0, h: distance(start)),
  ];
  final seen = <String>{start.join(',')};
  for (var count = 0; count < 2500 && queue.isNotEmpty; count++) {
    queue.sort((a, b) => (b.depth + b.h).compareTo(a.depth + a.h));
    final node = queue.removeLast();
    if (node.h == 0) {
      return node.first;
    }
    for (final index in neighbors(node.b, n)) {
      final b = List<int>.of(node.b), gap = b.indexOf(0);
      b[gap] = b[index];
      b[index] = 0;
      if (seen.add(b.join(','))) {
        queue.add((
          b: b,
          first: node.first < 0 ? index : node.first,
          depth: node.depth + 1,
          h: distance(b),
        ));
      }
    }
  }
  return null;
}
