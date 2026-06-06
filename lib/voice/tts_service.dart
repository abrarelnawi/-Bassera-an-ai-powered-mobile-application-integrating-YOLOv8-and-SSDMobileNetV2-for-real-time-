import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async'; // for Completer

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.42); // slow and clear for blind users
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // ✅ Wait for completion before returning
    _tts.setCompletionHandler(() {
      print("[TtsService] ✅ Speech completed");
    });

    _initialized = true;
    print("[TtsService] Initialized ✅");
  }

  Future<void> speak(String text) async {
    print("[TtsService] ▶ speak() → '$text'");

    try {
      await _ensureInit();
      await _tts.stop(); // stop anything playing

      // Speak and wait for it to finish
      final completer = Completer<void>();

      _tts.setCompletionHandler(() {
        print("[TtsService] ✅ Done speaking");
        if (!completer.isCompleted) completer.complete();
      });

      _tts.setErrorHandler((msg) {
        print("[TtsService] ❌ TTS error: $msg");
        if (!completer.isCompleted) completer.complete();
      });

      final result = await _tts.speak(text);
      print("[TtsService] speak() result: $result");

      // Wait for completion with timeout fallback
      final estimatedMs = (text.length / 10 * 1000 + 4000).toInt();
      print("[TtsService] Waiting up to ${estimatedMs}ms...");

      await completer.future.timeout(
        Duration(milliseconds: estimatedMs),
        onTimeout: () {
          print("[TtsService] ⏱ Timeout — assuming done");
        },
      );

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e, stack) {
      print("[TtsService] ❌ ERROR: $e");
      print("[TtsService] STACK: $stack");
    }
  }

  Future<void> stop() async {
    print("[TtsService] stop()");
    await _tts.stop();
  }

  void dispose() {
    print("[TtsService] dispose()");
    _tts.stop();
  }
}
