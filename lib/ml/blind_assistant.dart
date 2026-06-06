import 'dart:convert';
import 'package:http/http.dart' as http;
import 'spatial_analyzer.dart';
import '../utils/object_memory.dart';
import 'assistant_mode.dart';

class BlindAssistant {
  static const String _hermesUrl =
      'https://hermes.ai.unturf.com/v1/chat/completions';
  static const String _model = 'adamo1139/Hermes-3-Llama-3.1-8B-FP8-Dynamic';

  AssistantMode mode = AssistantMode.navigate;

  final ObjectMemory _memory = ObjectMemory();
  final List<Map<String, String>> _history = [];
  List<SpatialObject> _currentObjects = [];

  // Called every frame from camera
  void updateDetections(List<dynamic> rawDetections) {
    _currentObjects = SpatialAnalyzer.analyze(rawDetections);
    _memory.update(_currentObjects);
  }

  bool get hasDanger => SpatialAnalyzer.hasDanger(_currentObjects);

  List<SpatialObject> get dangerObjects =>
      SpatialAnalyzer.dangerObjects(_currentObjects);

  // Build scene summary string from spatial objects
  String _buildSceneSummary(List<SpatialObject> objects) {
    if (objects.isEmpty) return 'nothing detected clearly';
    return objects
        .map((o) {
          final dist = o.distance;
          final zone = o.zone;
          final conf = (o.score * 100).toStringAsFixed(0);
          return '${o.label} ($zone, $dist, ${conf}% confidence)';
        })
        .join('; ');
  }

  /// Describe current scene — called on startup and re-describe tap
  Future<String> describeScene() async {
    final objects = _memory.newObjects();
    _memory.markSpoken(objects.isEmpty ? _currentObjects : objects);

    final summary = _buildSceneSummary(
      objects.isEmpty ? _currentObjects : objects,
    );

    print('[BlindAssistant] describeScene() — $summary');

    final userMsg =
        'Camera detects: $summary. '
        'Describe the scene with spatial awareness. '
        '${mode.userPromptSuffix}';

    return _chat(userMsg, systemOverride: mode.systemPrompt);
  }

  /// Danger-specific alert — called immediately when danger found
  Future<String> dangerAlert() async {
    final dangers = dangerObjects
        .map((o) => '${o.label} (${o.zone}, ${o.distance})')
        .join(', ');

    print('[BlindAssistant] dangerAlert() — $dangers');

    const urgentSystem =
        'You are a safety alert system for a blind user. '
        'DANGER HAS BEEN DETECTED. '
        'Give an immediate, urgent warning. '
        'Start with WARNING. '
        'State what the danger is, where it is, and say STOP or exact avoidance action. '
        'Max 2 sentences. No fluff.';

    final userMsg = 'DANGER DETECTED: $dangers. Give urgent safety warning.';
    return _chat(userMsg, systemOverride: urgentSystem);
  }

  /// User asked a question via voice
  Future<String> respondToUser(String userSpeech) async {
    final context = _buildSceneSummary(_currentObjects);
    print('[BlindAssistant] respondToUser: "$userSpeech"');

    final userMsg =
        'Current scene: $context. '
        'User asks: "$userSpeech". '
        'Answer directly using the scene context. '
        '${mode.userPromptSuffix}';

    return _chat(userMsg, systemOverride: mode.systemPrompt);
  }

  /// Step-by-step guidance
  Future<String> getStepGuidance() async {
    final context = _buildSceneSummary(_currentObjects);

    const stepSystem =
        'You are a step-by-step navigation guide for a blind user. '
        'Give exactly ONE movement instruction based on what is visible. '
        'Format: [action] [direction] [distance hint]. '
        'Examples: "Turn slightly right." "Walk 2 steps forward." "Stop, obstacle ahead." '
        'One sentence only. Be precise.';

    final userMsg = 'Scene: $context. Give next movement step.';
    return _chat(userMsg, systemOverride: stepSystem, addToHistory: false);
  }

  Future<String> _chat(
    String userMessage, {
    String? systemOverride,
    bool addToHistory = true,
  }) async {
    if (addToHistory) {
      _history.add({'role': 'user', 'content': userMessage});
    }

    final recentHistory = _history.length > 10
        ? _history.sublist(_history.length - 10)
        : List.of(_history);

    final messages = [
      {'role': 'system', 'content': systemOverride ?? mode.systemPrompt},
      ...recentHistory,
    ];

    try {
      final response = await http
          .post(
            Uri.parse(_hermesUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer choose-any-value',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0.6,
              'max_tokens': 140,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 25));

      print('[BlindAssistant] HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply =
            data['choices']?[0]?['message']?['content']?.toString().trim() ??
            'Please try again.';

        if (addToHistory) {
          _history.add({'role': 'assistant', 'content': reply});
        }

        print('[BlindAssistant] Reply: $reply');
        return reply;
      }

      return 'Could not get a response. Please try again.';
    } catch (e, stack) {
      print('[BlindAssistant] ERROR: $e');
      print('[BlindAssistant] STACK: $stack');
      return 'Something went wrong. Please try again.';
    }
  }

  void setMode(AssistantMode m) {
    mode = m;
    _history.clear();
    print('[BlindAssistant] Mode → ${m.label}');
  }

  void clearHistory() {
    _history.clear();
    _memory.clear();
  }
}
