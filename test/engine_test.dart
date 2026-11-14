import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuffle_slide/features/puzzle_engine/engine.dart';
import 'package:shuffle_slide/data/progress.dart';

void main() {
  for (final mode in PuzzleMode.values) {
    test('${mode.name}: exactly 50 progressive level definitions', () {
      final levels = Level.all(mode);
      expect(levels.length, 50);
      expect(levels.map((e) => e.id).toSet().length, 50);
      expect(levels.first.seconds, 180);
      expect(levels.last.seconds, 300);
      for (var i = 1; i < levels.length; i++) {
        if (levels[i].size == levels[i - 1].size) {
          expect(
            levels[i].scramble,
            greaterThanOrEqualTo(levels[i - 1].scramble),
          );
          expect(levels[i].seconds, lessThan(levels[i - 1].seconds));
        }
      }
    });
    test(
      '${mode.name}: all levels have reversible, deterministic, solvable shuffles',
      () {
        for (final level in Level.all(mode)) {
          for (var seed = 0; seed < 10; seed++) {
            final a = Attempt.start(level, seed);
            expect(a.board.toSet().length, level.size * level.size);
            expect(a.board.where((v) => v == 0).length, 1);
            expect(a.finished, isFalse);
            expect(isSolved(a.board), isFalse);
            expect(a.board, Attempt.start(level, seed).board);
            var iterations = 0;
            while (!a.finished && iterations++ < level.scramble + 2) {
              final index = a.board.indexOf(a.trail.last);
              expect(neighbors(a.board, level.size), contains(index));
              expect(a.move(index), isTrue);
            }
            expect(a.finished, isTrue, reason: 'Level ${level.id} seed $seed');
            expect(a.board, solvedBoard(level.size));
          }
        }
      },
    );
  }
  Attempt custom(List<int> board) {
    final a = Attempt.start(Level.all(PuzzleMode.number).first, 42);
    a.board = board;
    return a;
  }

  test(
    'multi-tile movement displaces and counts each tile; one undo restores all',
    () {
      final a = custom([1, 2, 3, 4, 5, 6, 0, 7, 8]);
      final before = List<int>.of(a.board);
      expect(a.move(0), isTrue);
      expect(a.moves, 2);
      expect(a.board, [0, 2, 3, 1, 5, 6, 4, 7, 8]);
      expect(a.undo(), isTrue);
      expect(a.board, before);
      expect(a.undos, 1);
      expect(a.penalties, 20);
    },
  );
  test('rejects invalid and gap input without changing state', () {
    final a = custom([1, 2, 3, 4, 0, 5, 6, 7, 8]);
    final before = List<int>.of(a.board);
    for (final index in [-1, 9, 4, 0, 2, 6, 8]) {
      expect(a.move(index), isFalse);
    }
    expect(a.board, before);
    expect(a.moves, 0);
    expect(a.history, isEmpty);
  });
  test('awards eligible placements once, including after undo', () {
    final a = custom([1, 2, 3, 4, 5, 6, 0, 8, 7]);
    a.move(7);
    expect(a.placement, 0); // 8 moves to position 6, not correct
    a.move(6);
    expect(a.placement, 100); // 8 returns to position 7
    final total = a.placement;
    a.undo();
    a.move(6);
    expect(a.placement, total);
    expect(a.penalties, 20);
  });
  test(
    'combos within 2 seconds, reset on incorrect placement, capped multiplier',
    () {
      final a = custom([1, 2, 3, 4, 0, 6, 7, 5, 8]);
      a.move(7);
      expect(a.placement, 100);
      expect(a.comboReward, 0);
      a.elapsedMs = 1500;
      a.move(8);
      expect(a.placement, 200);
      expect(a.comboReward, 10);
      expect(a.finished, isTrue);
    },
  );
  test('undo limit and hint penalties never create negative scores', () {
    final a = Attempt.start(Level.all(PuzzleMode.photo).first, 10);
    for (var i = 0; i < 4; i++) {
      a.move(neighbors(a.board, 3).first);
    }
    for (var i = 0; i < 3; i++) {
      expect(a.undo(), isTrue);
    }
    expect(a.undo(), isFalse);
    for (var i = 0; i < 3; i++) {
      expect(a.hint(), isNotNull);
    }
    expect(a.hint(), isNull);
    expect(a.score, greaterThanOrEqualTo(0));
    expect(a.penalties, 510);
  });
  test('timer expiry prevents moves and undo', () {
    final a = Attempt.start(Level.all(PuzzleMode.number).first, 3);
    a.elapsedMs = a.level.seconds * 1000;
    expect(a.remaining, 0);
    expect(a.move(neighbors(a.board, 3).first), isFalse);
    expect(a.undo(), isFalse);
    expect(a.hint(), isNull);
  });
  test('score breakdown and star rules', () {
    final a = custom([1, 2, 3, 4, 5, 6, 7, 0, 8]);
    a.elapsedMs = 1000;
    a.move(8);
    expect(
      a.finalScore,
      a.placement + a.comboReward + a.timeBonus + a.moveBonus - a.penalties,
    );
    expect(a.stars, 3);
    a.hintsUsed = 1;
    expect(a.stars, 2);
    a.penalties = 100000;
    expect(a.finalScore, 0);
    expect(a.stars, 1);
  });
  test(
    'save roundtrip restores board, path, history, penalties, timer and awards',
    () {
      final a = Attempt.start(Level.all(PuzzleMode.photo)[20], 123);
      a.move(neighbors(a.board, 4).first);
      a.hint();
      a.elapsedMs = 12345;
      a.photoPath = '/local/photo.jpg';
      final b = Attempt.fromJson(jsonDecode(jsonEncode(a.toJson())));
      expect(b.toJson(), a.toJson());
      expect(b.undo(), isTrue);
      expect(b.undos, 1);
    },
  );
  test('small-board search recommends a legal solution move', () {
    expect(
      searchHint({
        'board': [1, 2, 3, 4, 5, 6, 7, 0, 8],
        'size': 3,
      }),
      8,
    );
    expect(searchHint({'board': solvedBoard(6), 'size': 6}), isNull);
  });
  test(
    'progress merge preserves best values independently and is idempotent',
    () {
      final local = {
        'number_1': {'score': 1000, 'stars': 2, 'time': 80, 'moves': 30},
      };
      final remote = {
        'number_1': {'score': 900, 'stars': 3, 'time': 90, 'moves': 20},
        'photo_1': {'score': 600, 'stars': 1, 'time': 70, 'moves': 28},
      };
      final merged = mergeResults(local, remote);
      expect(merged['number_1'], {
        'score': 1000,
        'stars': 3,
        'time': 80,
        'moves': 20,
      });
      expect(mergeResults(merged, remote), merged);
      expect(mergeResults(remote, local), merged);
      expect(unlockedLevel(merged, PuzzleMode.number), 2);
      expect(unlockedLevel(local, PuzzleMode.photo), 1);
    },
  );
}
