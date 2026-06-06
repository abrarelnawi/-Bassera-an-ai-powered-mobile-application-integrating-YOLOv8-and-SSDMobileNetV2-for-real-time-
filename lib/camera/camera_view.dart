import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../ml/tflite_service.dart';
import '../ml/blind_assistant.dart';
import '../voice/speech_service.dart';
import '../voice/tts_service.dart';
import '../utils/shake_detector.dart';
import '../ml/assistant_mode.dart';
import '../ui/overlay_painter.dart';

enum ViewState { idle, describing, speaking, listening, thinking, danger }

class CameraView extends StatefulWidget {
  final CameraController controller;
  final TFLiteService service;

  const CameraView({
    super.key,
    required this.controller,
    required this.service,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView>
    with SingleTickerProviderStateMixin {
  List<dynamic>? _recognitions;

  bool _isBusy = false;
  int _frameCount = 0;
  static const int _skipFrames = 3;

  final BlindAssistant _assistant = BlindAssistant();
  final SpeechService _stt = SpeechService();
  final TtsService _tts = TtsService();
  final ShakeDetector _shake = ShakeDetector();

  ViewState _state = ViewState.idle;
  String _statusText = 'Starting...';
  bool _loopActive = false;

  // Danger: track last warned to avoid spam
  String _lastDangerKey = '';
  DateTime _lastDangerTime = DateTime(2000);

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Step guidance timer
  Timer? _stepTimer;
  bool _stepModeActive = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _stt.init().then((_) {
      _shake.start(_onDoubleShake);
      Future.delayed(const Duration(seconds: 2), _describeScene);
    });

    widget.controller.startImageStream(_onFrame);
  }

  // ─── Camera loop ─────────────────────────────────────────────────────────

  void _onFrame(CameraImage image) {
    _frameCount++;
    if (_frameCount % _skipFrames != 0) return;
    if (_isBusy) return;
    _runModel(image);
  }

  Future<void> _runModel(CameraImage image) async {
    _isBusy = true;
    try {
      final results = await widget.service.detect(image);
      if (!mounted) return;

      setState(() => _recognitions = results);

      if (results != null) {
        _assistant.updateDetections(results);

        // Check for new danger
        if (_assistant.hasDanger) _checkDanger();
      }
    } catch (e) {
      print('Detection error: $e');
    } finally {
      _isBusy = false;
    }
  }

  // ─── Danger detection ────────────────────────────────────────────────────

  void _checkDanger() async {
    final dangers = _assistant.dangerObjects;
    if (dangers.isEmpty) return;

    final key = dangers.map((d) => '${d.label}_${d.zone}').join(',');
    final now = DateTime.now();

    // Only alert if new danger or same danger after 15s cooldown
    if (key == _lastDangerKey && now.difference(_lastDangerTime).inSeconds < 15)
      return;

    _lastDangerKey = key;
    _lastDangerTime = now;

    print('[CameraView] 🚨 Danger: $key');

    // Interrupt current speech
    await _tts.stop();
    _loopActive = false;

    // Long vibration for danger
    final canVibrate = await Vibration.hasVibrator() ?? false;
    if (canVibrate) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500],
        intensities: [0, 255, 0, 255],
      );
    }

    _setUiState(ViewState.danger, '🚨 Danger detected!');

    final alert = await _assistant.dangerAlert();

    // Speak danger twice
    _setUiState(ViewState.speaking, alert);
    await _tts.speak(alert);
    await Future.delayed(const Duration(milliseconds: 600));
    await _tts.speak(alert); // repeat for safety

    _setUiState(ViewState.idle, 'Shake twice to ask a question');
  }

  // ─── Describe + speak ────────────────────────────────────────────────────

  Future<void> _describeScene() async {
    if (_loopActive) return;
    _loopActive = true;

    _setUiState(ViewState.describing, '👁 Analyzing scene...');
    final desc = await _assistant.describeScene();

    // Short vibration: new description
    final canVibrate = await Vibration.hasVibrator() ?? false;
    if (canVibrate) Vibration.vibrate(duration: 80);

    _setUiState(ViewState.speaking, desc);
    await _tts.speak(desc);

    _setUiState(ViewState.idle, 'Shake twice to ask a question');
    _loopActive = false;
  }

  // ─── Shake → listen ──────────────────────────────────────────────────────

  void _onDoubleShake() {
    print('[CameraView] Double shake!');
    if (_state == ViewState.speaking) _tts.stop();
    if (_loopActive) {
      _loopActive = false;
      Future.delayed(const Duration(milliseconds: 300), _startListening);
    } else {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (_loopActive) return;
    _loopActive = true;

    // Short vibrate on listen start
    final canVibrate = await Vibration.hasVibrator() ?? false;
    if (canVibrate) Vibration.vibrate(duration: 60);

    _setUiState(ViewState.listening, '🎙 Listening...');

    bool gotResult = false;

    await _stt.startListening((transcript) async {
      if (gotResult) return;
      gotResult = true;

      print('[CameraView] Heard: "$transcript"');

      if (transcript.trim().isEmpty) {
        await _tts.speak("I didn't catch that. Shake twice to try again.");
        _setUiState(ViewState.idle, 'Shake twice to ask a question');
        _loopActive = false;
        return;
      }

      _setUiState(ViewState.thinking, '💭 "${transcript}"');
      final reply = await _assistant.respondToUser(transcript);

      _setUiState(ViewState.speaking, reply);
      await _tts.speak(reply);

      _setUiState(ViewState.idle, 'Shake twice to ask a question');
      _loopActive = false;
    });

    // Timeout
    await Future.delayed(const Duration(seconds: 12));
    if (_state == ViewState.listening && mounted) {
      await _stt.stopListening();
      await _tts.speak("I didn't hear anything. Shake twice to try again.");
      _setUiState(ViewState.idle, 'Shake twice to ask a question');
      _loopActive = false;
    }
  }

  // ─── Step guidance mode ──────────────────────────────────────────────────

  void _toggleStepMode() {
    setState(() => _stepModeActive = !_stepModeActive);

    if (_stepModeActive) {
      _tts.speak('Step guidance mode on.');
      _stepTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (_loopActive) return;
        final step = await _assistant.getStepGuidance();
        _setUiState(ViewState.speaking, step);
        await _tts.speak(step);
        if (_state == ViewState.speaking) {
          _setUiState(ViewState.idle, 'Step guidance active');
        }
      });
    } else {
      _stepTimer?.cancel();
      _tts.speak('Step guidance off.');
    }
  }

  // ─── Mode selector ───────────────────────────────────────────────────────

  void _cycleMode() {
    final modes = AssistantMode.values;
    final next = modes[(_assistant.mode.index + 1) % modes.length];
    _assistant.setMode(next);
    _tts.speak('${next.label} mode.');
    setState(() {});
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _setUiState(ViewState s, String text) {
    if (!mounted) return;
    setState(() {
      _state = s;
      _statusText = text;
    });
  }

  Future<void> _onDescribeTap() async {
    await _tts.stop();
    await _stt.stopListening();
    _loopActive = false;
    _assistant.clearHistory();
    await Future.delayed(const Duration(milliseconds: 200));
    await _describeScene();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stepTimer?.cancel();
    _shake.stop();
    _tts.dispose();
    _stt.dispose();
    widget.controller.stopImageStream();
    widget.service.close();
    super.dispose();
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool active = _state != ViewState.idle;

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(widget.controller),

        if (_recognitions != null && _recognitions!.isNotEmpty)
          OverlayPainter(_recognitions!),

        // Border glow
        if (active)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _stateColor().withOpacity(0.6),
                    width: 4,
                  ),
                ),
              ),
            ),
          ),

        // Status card
        Positioned(
          top: 52,
          left: 12,
          right: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_statusText),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _state == ViewState.danger
                    ? Colors.red.withOpacity(0.92)
                    : Colors.black.withOpacity(0.82),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _stateColor().withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale:
                          (_state == ViewState.listening ||
                              _state == ViewState.danger)
                          ? _pulseAnim.value
                          : 1.0,
                      child: child,
                    ),
                    child: Icon(_stateIcon(), color: _stateColor(), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Mode badge
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _cycleMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _assistant.mode.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 44,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Step mode toggle
              _ControlButton(
                icon: _stepModeActive
                    ? Icons.directions_walk
                    : Icons.directions_walk_outlined,
                label: _stepModeActive ? 'Steps ON' : 'Steps',
                color: _stepModeActive ? Colors.greenAccent : Colors.white,
                onTap: _toggleStepMode,
                pulse: _stepModeActive,
                pulseAnim: _pulseAnim,
              ),

              // Main describe button
              GestureDetector(
                onTap: _onDescribeTap,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: active ? _pulseAnim.value : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.75),
                      border: Border.all(color: _stateColor(), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _stateColor().withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(_stateIcon(), color: _stateColor(), size: 34),
                  ),
                ),
              ),

              // Mode cycle button
              _ControlButton(
                icon: Icons.tune,
                label: 'Mode',
                color: Colors.white,
                onTap: _cycleMode,
                pulse: false,
                pulseAnim: _pulseAnim,
              ),
            ],
          ),
        ),

        // Shake hint
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Text(
            _state == ViewState.idle ? '📳 Shake twice to ask' : _stateLabel(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _stateColor().withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              shadows: [const Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }

  Color _stateColor() => switch (_state) {
    ViewState.danger => Colors.redAccent,
    ViewState.listening => Colors.redAccent,
    ViewState.speaking => Colors.greenAccent,
    ViewState.thinking => Colors.amberAccent,
    ViewState.describing => Colors.blueAccent,
    ViewState.idle => Colors.white,
  };

  IconData _stateIcon() => switch (_state) {
    ViewState.danger => Icons.warning_amber_rounded,
    ViewState.listening => Icons.mic,
    ViewState.speaking => Icons.volume_up,
    ViewState.thinking => Icons.psychology,
    ViewState.describing => Icons.visibility,
    ViewState.idle => Icons.visibility_outlined,
  };

  String _stateLabel() => switch (_state) {
    ViewState.danger => 'DANGER',
    ViewState.listening => 'LISTENING',
    ViewState.speaking => 'SPEAKING',
    ViewState.thinking => 'THINKING',
    ViewState.describing => 'DESCRIBING',
    ViewState.idle => 'TAP TO DESCRIBE',
  };
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool pulse;
  final Animation<double> pulseAnim;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.pulse,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.65),
              border: Border.all(color: color, width: 1.8),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [const Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
    return pulse ? ScaleTransition(scale: pulseAnim, child: btn) : btn;
  }
}
