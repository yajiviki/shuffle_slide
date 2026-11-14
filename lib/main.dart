import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'app.dart';

final storeProvider = Provider<GameStore>(
  (ref) => throw UnimplementedError('Store is overridden at startup'),
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = GameStore(await SharedPreferences.getInstance());
  await createSampleImage();
  await store.initialize();
  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: const ShuffleApp(),
    ),
  );
}
