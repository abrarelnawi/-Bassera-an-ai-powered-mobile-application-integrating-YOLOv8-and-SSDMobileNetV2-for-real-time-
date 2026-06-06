import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready = false;

  Future<void> init() async {
    print("[SpeechService] init() called");
    _ready = await _stt.initialize(
      onError: (e) => print('[SpeechService] STT error: $e'),
      onStatus: (s) => print('[SpeechService] STT status: $s'),
    );
    print("[SpeechService] STT ready: $_ready");
  }

  bool get isListening => _stt.isListening;

  Future<void> startListening(void Function(String text) onResult) async {
    print("[SpeechService] startListening() called — ready: $_ready");
    if (!_ready) {
      print("[SpeechService] Not ready — aborting");
      return;
    }

    await _stt.listen(
      onResult: (result) {
        print(
          "[SpeechService] onResult — final: ${result.finalResult}, words: '${result.recognizedWords}'",
        );
        if (result.finalResult) onResult(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
    );

    print("[SpeechService] listen() started");
  }

  Future<void> stopListening() async {
    print("[SpeechService] stopListening() called");
    await _stt.stop();
  }

  void dispose() {
    print("[SpeechService] dispose() called");
    _stt.cancel();
  }
}
