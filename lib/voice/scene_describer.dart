import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../ml/postprocessor.dart';

class SceneDescriber {
  static const String _hermesUrl =
      "https://hermes.ai.unturf.com/v1/chat/completions";
  static const String _model = "adamo1139/Hermes-3-Llama-3.1-8B-FP8-Dynamic";

  static Future<String> describe(List<Detection> detections) async {
    print("[SceneDescriber] describe() — ${detections.length} detections");

    if (detections.isEmpty) {
      print("[SceneDescriber] No detections");
      return "I don't see anything clearly right now. "
          "Please point the camera at your surroundings.";
    }

    final summary = detections
        .map((d) {
          final pct = (d.score * 100).toStringAsFixed(0);
          return '${d.label} ($pct%)';
        })
        .join(', ');

    print("[SceneDescriber] Detected: $summary");

    final prompt =
        'The camera detected: $summary. '
        'Describe the scene in 3-4 warm natural sentences for a blind person. '
        'Mention where things are (left, right, ahead, nearby). '
        'After describing, give one clear action: move, stop, turn, reach, or be careful.'
        'End by saying: Shake the phone twice if you have a question.';

    try {
      print("[SceneDescriber] Calling Hermes...");

      final response = await http
          .post(
            Uri.parse(_hermesUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer choose-any-value',
            },
            body: jsonEncode({
              "model": _model,
              "temperature": 0.7,
              "max_tokens": 180, // more tokens = richer description
              "messages": [
                {
                  "role": "system",
                  "content":
                      "You are a warm, descriptive voice assistant helping a blind person "
                      "understand their surroundings. Always mention spatial positions. "
                      "Never use markdown or lists. Speak naturally as if talking to a friend.",
                },
                {"role": "user", "content": prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30)); // ✅ 30s timeout

      print("[SceneDescriber] HTTP ${response.statusCode}");
      print("[SceneDescriber] Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content']
            ?.toString()
            .trim();
        print("[SceneDescriber] ✅ Description: $text");
        return text ??
            "I can see some objects but couldn't describe them. "
                "Shake twice to ask me directly.";
      } else {
        print("[SceneDescriber] ❌ ${response.statusCode}: ${response.body}");
        return "I see: ${detections.map((d) => d.label).join(', ')}. "
            "Shake twice to ask me anything.";
      }
    } catch (e, stack) {
      print("[SceneDescriber] ❌ ERROR: $e");
      print("[SceneDescriber] STACK: $stack");
      return "I see: ${detections.map((d) => d.label).join(', ')}. "
          "Shake twice to ask me anything.";
    }
  }
}
