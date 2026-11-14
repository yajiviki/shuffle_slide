import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/puzzle_engine/engine.dart';
import 'progress.dart';

class GameStore extends ChangeNotifier {
  final SharedPreferences prefs;
  bool firebaseReady = false, busy = false;
  String? syncError;
  String? configError;
  Json results = {}, attempts = {};
  Json settings = {
    'dark': true,
    'sound': true,
    'haptic': true,
    'reduceMotion': false,
    'largeText': false,
  };
  List<String> photos = [];
  String? selectedPhoto;
  Attempt? saved;
  bool guest = false;
  bool _syncing = false;
  bool _syncAgain = false;
  Future<void> _writes = Future.value();
  GameStore(this.prefs) {
    try {
      results = Map<String, dynamic>.from(
        jsonDecode(prefs.getString('results') ?? '{}'),
      );
      attempts = Map<String, dynamic>.from(
        jsonDecode(prefs.getString('attempts') ?? '{}'),
      );
      settings.addAll(
        Map<String, dynamic>.from(
          jsonDecode(prefs.getString('settings') ?? '{}'),
        ),
      );
      photos = prefs.getStringList('photos') ?? [];
      selectedPhoto = prefs.getString('selectedPhoto');
      if (selectedPhoto != null && !File(selectedPhoto!).existsSync()) {
        selectedPhoto = null;
      }
      final raw = prefs.getString('saved');
      if (raw != null) {
        saved = Attempt.fromJson(jsonDecode(raw));
      }
      guest = prefs.getBool('guest') ?? false;
    } catch (_) {
      configError = 'Some saved data could not be restored.';
    }
  }
  User? get user => firebaseReady ? FirebaseAuth.instance.currentUser : null;
  bool get signedIn => guest || user != null;
  String get name => user?.displayName ?? 'Guest explorer';
  int get totalStars =>
      results.values.fold(0, (int sum, e) => sum + (e['stars'] as int));
  int get completed => results.length;
  int get totalScore =>
      results.values.fold(0, (int sum, e) => sum + (e['score'] as int));
  Future<void> initialize() async {
    try {
      // Native configuration is supplied by the owner's Firebase project.
      await Firebase.initializeApp();
      firebaseReady = true;
      FirebaseAuth.instance.authStateChanges().listen((_) {
        notifyListeners();
        unawaited(sync());
      });
      unawaited(sync());
    } catch (_) {
      configError = 'Firebase is not configured. Offline play is available. See README for connecting your existing project.';
    }
    notifyListeners();
  }

  Future<void> persist() {
    final snapshot = {
      'results': jsonEncode(results),
      'attempts': jsonEncode(attempts),
      'settings': jsonEncode(settings),
      'photos': List<String>.of(photos),
      'photo': selectedPhoto,
      'saved': saved == null ? null : jsonEncode(saved!.toJson()),
      'guest': guest,
    };
    _writes = _writes.catchError((_) {}).then((_) async {
      for (final key in ['results', 'attempts', 'settings']) {
        await prefs.setString(key, snapshot[key] as String);
      }
      await prefs.setStringList('photos', snapshot['photos'] as List<String>);
      if (snapshot['photo'] == null) {
        await prefs.remove('selectedPhoto');
      } else {
        await prefs.setString('selectedPhoto', snapshot['photo'] as String);
      }
      if (snapshot['saved'] == null) {
        await prefs.remove('saved');
      } else {
        await prefs.setString('saved', snapshot['saved'] as String);
      }
      await prefs.setBool('guest', snapshot['guest'] as bool);
    });
    return _writes;
  }

  Future<void> loginGuest() async {
    guest = true;
    await persist();
    notifyListeners();
    unawaited(sync());
  }

  Future<String?> loginGoogle({required bool reconcileExisting}) async {
    if (!firebaseReady) {
      return configError;
    }
    busy = true;
    notifyListeners();
    try {
      final google = GoogleSignIn.instance;
      await google.initialize();
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        return 'Google did not return an ID token.';
      }
      final credential = GoogleAuthProvider.credential(idToken: token);
      if (user?.isAnonymous == true) {
        try {
          await user!.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use') {
            rethrow;
          }
          if (!reconcileExisting) {
            return 'This Google account already exists. Confirm merging to preserve both sets of progress.';
          }
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      guest = true;
      await persist();
      await sync();
      return null;
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? 'Sign-in canceled. Your progress is safe.'
          : 'Google sign-in failed: ${e.description ?? e.code.name}';
    } on FirebaseAuthException catch (e) {
      return 'Sign-in failed: ${e.code}. ${e.message ?? ''}';
    } catch (e) {
      return 'Sign-in unavailable: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (!firebaseReady) {
      return;
    }
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      if (user == null && guest) {
        await FirebaseAuth.instance.signInAnonymously().timeout(
          const Duration(seconds: 15),
        );
      }
      final uid = user?.uid;
      if (uid == null) {
        return;
      }
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final localResults = Map<String, dynamic>.from(results),
          localAttempts = Map<String, dynamic>.from(attempts);
      final merged = await FirebaseFirestore.instance
          .runTransaction((tx) async {
            final remote = (await tx.get(ref)).data() ?? {};
            final mergedResults = mergeResults(
              Map<String, dynamic>.from(remote['results'] ?? {}),
              localResults,
            );
            final mergedAttempts = {
              ...Map<String, dynamic>.from(remote['attempts'] ?? {}),
              ...localAttempts,
            };
            tx.set(ref, {
              'displayName': name,
              'provider': user?.isAnonymous == true ? 'guest' : 'google',
              'results': mergedResults,
              'attempts': mergedAttempts,
              'lastLoginAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            return {'results': mergedResults, 'attempts': mergedAttempts};
          })
          .timeout(const Duration(seconds: 15));
      results = mergeResults(
        results,
        Map<String, dynamic>.from(merged['results']!),
      );
      attempts = {
        ...Map<String, dynamic>.from(merged['attempts']!),
        ...attempts,
      };
      syncError = null;
      await persist();
    } catch (_) {
      syncError = 'Progress is saved on this device. Cloud sync is pending; tap Sync when online.';
    } finally {
      _syncing = false;
      notifyListeners();
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(sync());
      }
    }
  }

  Future<bool> complete(Attempt attempt) async {
    final key = resultKey(attempt.level.mode, attempt.level.id);
    final best = attempt.finalScore > (results[key]?['score'] ?? -1);
    results = mergeResults(results, {
      key: {
        'score': attempt.finalScore,
        'stars': attempt.stars,
        'time': attempt.elapsedMs ~/ 1000,
        'moves': attempt.moves,
      },
    });
    // Unique attempts make repeated syncs idempotent.
    attempts['${attempt.level.mode.name}_${attempt.level.id}_${attempt.seed}'] =
        {'moves': attempt.moves, 'time': attempt.elapsedMs ~/ 1000};
    saved = null;
    await persist();
    notifyListeners();
    unawaited(sync());
    return best;
  }

  Future<void> setSetting(String key, bool value) async {
    settings[key] = value;
    await persist();
    notifyListeners();
  }

  Future<void> selectPhoto(String? path) async {
    selectedPhoto = path;
    await persist();
    notifyListeners();
  }

  Future<void> importPhoto(String source) async {
    final dir = await getApplicationDocumentsDirectory();
    final destination =
        '${dir.path}/puzzle_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final bytes = await File(source).readAsBytes();
    if (bytes.length > 30 * 1024 * 1024) {
      throw const FormatException('Image exceeds 30 MB');
    }
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
    final frame = await codec.getNextFrame();
    final square = frame.image.width == frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (!square) {
      throw const FormatException('Crop the image to a square first');
    }
    await File(source).copy(destination);
    photos.add(destination);
    selectedPhoto = destination;
    await persist();
    notifyListeners();
  }

  Future<void> removePhoto(String path) async {
    photos.remove(path);
    if (selectedPhoto == path) {
      selectedPhoto = null;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await persist();
    notifyListeners();
  }

  Future<void> signOut() async {
    if (firebaseReady) {
      await FirebaseAuth.instance.signOut();
    }
    guest = false;
    await persist();
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    if (_syncing) {
      return 'Cloud sync is still finishing. Please retry deletion in a moment.';
    }
    try {
      if (user != null) {
        final current = user!;
        // Check recent authentication before deleting any progress.
        final signedInAt = current.metadata.lastSignInTime;
        if (!current.isAnonymous &&
            (signedInAt == null ||
                DateTime.now().difference(signedInAt) >
                    const Duration(minutes: 5))) {
          return 'For account deletion, sign out and sign in again first. Your progress is retained.';
        }
        await current.getIdToken(true);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(current.uid)
            .delete();
        await current.delete();
      }
      results = {};
      attempts = {};
      saved = null;
      for (final path in List<String>.of(photos)) {
        await removePhoto(path);
      }
      guest = false;
      await persist();
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return 'Account deletion failed: ${e.code}. Sign in again and retry. Local progress is retained.';
    } catch (_) {
      return 'Account deletion could not finish. Retry online.';
    }
  }
}

Future<void> createSampleImage() async {
  // Generated locally: no network or gallery permissions needed.
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, 900, 900);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xfff4b882), Color(0xffd7a9a2), Color(0xff827aaf)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect),
  );
  canvas.drawCircle(
    const Offset(650, 250),
    102,
    Paint()..color = const Color(0xffffe8ad),
  );
  for (var layer = 0; layer < 4; layer++) {
    final path = Path()..moveTo(0, 470 + layer * 105.0);
    for (var i = 0; i <= 9; i++) {
      path.lineTo(
        i * 112.5,
        320 + layer * 105 + (i.isEven ? 80 : -65) + (i % 3) * 35,
      );
    }
    path
      ..lineTo(900, 900)
      ..lineTo(0, 900)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = [
          const Color(0xff9086a3),
          const Color(0xff616987),
          const Color(0xff364c69),
          const Color(0xff19374e),
        ][layer],
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(900, 900),
      data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getApplicationDocumentsDirectory();
  await File('${dir.path}/sample.png').writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}
