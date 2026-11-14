import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_cropper_platform_interface/image_cropper_platform_interface.dart';
import 'package:shuffle_slide/app.dart';
import 'package:shuffle_slide/main.dart';
import 'package:shuffle_slide/data/store.dart';
import 'package:shuffle_slide/features/puzzle_engine/engine.dart';
import 'package:shuffle_slide/features/game/game_screen.dart';

class Paths extends PathProviderPlatform {
  final String path;
  Paths(this.path);
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
}

class Picker extends ImagePickerPlatform {
  String? path;
  Picker(this.path);
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => path == null ? null : XFile(path!);
}

class Cropper extends ImageCropperPlatform {
  final String path;
  CropAspectRatio? ratio;
  Cropper(this.path);
  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    ratio = aspectRatio;
    return CroppedFile(path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('shuffle_test');
    PathProviderPlatform.instance = Paths(dir.path);
    SharedPreferences.setMockInitialValues({});
    await createSampleImage();
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Future<GameStore> store() async =>
      GameStore(await SharedPreferences.getInstance());
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  test(
    'photo import creates a private copy; deleting it leaves original intact',
    () async {
      final s = await store(), source = File('${dir.path}/sample.png');
      await s.importPhoto(source.path);
      expect(s.selectedPhoto, isNot(source.path));
      expect(
        await File(s.selectedPhoto!).readAsBytes(),
        await source.readAsBytes(),
      );
      final copy = s.selectedPhoto!;
      await s.removePhoto(copy);
      expect(await source.exists(), isTrue);
      expect(await File(copy).exists(), isFalse);
      expect(s.selectedPhoto, isNull);
    },
  );
  testWidgets(
    'gallery workflow requests square crop and saves selected photo',
    (tester) async {
      final s = await store();
      ImagePickerPlatform.instance = Picker('${dir.path}/sample.png');
      final cropper = Cropper('${dir.path}/sample.png');
      ImageCropperPlatform.instance = cropper;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeProvider.overrideWithValue(s)],
          child: const MaterialApp(home: PhotoLibraryScreen()),
        ),
      );
      await flush(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose Photo from Gallery'));
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await flush(tester);
      expect(cropper.ratio!.ratioX, 1);
      expect(cropper.ratio!.ratioY, 1);
      expect(s.photos.length, 1);
      expect(s.selectedPhoto, isNotNull);
      await tester.scrollUntilVisible(find.text('Your photo'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Your photo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );
  testWidgets('canceling the native picker preserves the selected photo', (
    tester,
  ) async {
    final s = await store();
    ImagePickerPlatform.instance = Picker(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(s)],
        child: const MaterialApp(home: PhotoLibraryScreen()),
      ),
    );
    await flush(tester);
    await tester.tap(find.text('Choose Photo from Gallery'));
    await flush(tester);
    expect(s.photos, isEmpty);
    expect(s.selectedPhoto, isNull);
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
  });
  testWidgets('photo puzzle renders shared image sections and completes', (
    tester,
  ) async {
    final s = await store();
    await s.loginGuest();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final a = Attempt.start(Level.all(PuzzleMode.photo).first, 42);
    a.photoPath = '${dir.path}/sample.png';
    a.board = [1, 2, 3, 4, 5, 6, 7, 0, 8];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(s)],
        child: MaterialApp(home: GameScreen(attempt: a)),
      ),
    );
    await flush(tester);
    expect(find.byType(Image).evaluate().length, greaterThanOrEqualTo(8));
    await tester.ensureVisible(find.byKey(const ValueKey(8)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey(8)));
    await tester.pump(const Duration(milliseconds: 200));
    await flush(tester);
    expect(find.text('A beautiful finish.'), findsOneWidget);
    expect(s.results['photo_1'], isNotNull);
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
  });
  testWidgets('renders home and gameplay previews at phone dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/Manrope.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final s = await store();
    await s.loginGuest();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(s)],
        child: const ShuffleApp(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home.png'),
    );
    final a = Attempt.start(Level.all(PuzzleMode.number).first, 42);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(s)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Manrope',
            scaffoldBackgroundColor: const Color(0xff111321),
          ),
          home: GameScreen(attempt: a),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/number.png'),
    );
    await tester.runAsync(() async {
      PaintingBinding.instance.imageCache.clear();
      await precacheImage(
        ResizeImage(FileImage(File('${dir.path}/sample.png')), width: 1200),
        tester.element(find.byType(MaterialApp)),
      );
    });
    await tester.pumpWidget(const SizedBox());
    final photo = Attempt.start(Level.all(PuzzleMode.photo).first, 42)
      ..photoPath = '${dir.path}/sample.png';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(s)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Manrope',
            scaffoldBackgroundColor: const Color(0xff111321),
          ),
          home: GameScreen(attempt: photo),
        ),
      ),
    );
    await flush(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/photo.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
  }, skip: !const bool.fromEnvironment('RENDER_PREVIEWS'));
}
