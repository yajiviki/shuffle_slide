import 'dart:math';

import '../features/puzzle_engine/engine.dart';

typedef Json = Map<String, dynamic>;

Json mergeResults(Json left, Json right) {
  final output = <String, dynamic>{...left};
  for (final key in right.keys) {
    final a = Map<String, dynamic>.from(output[key] ?? {});
    final b = Map<String, dynamic>.from(right[key]);
    output[key] = {
      'score': max((a['score'] ?? 0) as int, (b['score'] ?? 0) as int),
      'stars': max((a['stars'] ?? 0) as int, (b['stars'] ?? 0) as int),
      'time': min((a['time'] ?? 1 << 30) as int, (b['time'] ?? 1 << 30) as int),
      'moves': min(
        (a['moves'] ?? 1 << 30) as int,
        (b['moves'] ?? 1 << 30) as int,
      ),
    };
  }
  return output;
}

String resultKey(PuzzleMode mode, int level) => '${mode.name}_$level';
int unlockedLevel(Json results, PuzzleMode mode) {
  var unlocked = 1;
  while (unlocked < 50 && results.containsKey(resultKey(mode, unlocked))) {
    unlocked++;
  }
  return unlocked;
}
