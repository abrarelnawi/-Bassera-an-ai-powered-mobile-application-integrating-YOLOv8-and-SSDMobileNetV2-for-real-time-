import 'labels.dart';

class Detection {
  final String label;
  final double score;
  final double x;
  final double y;
  final double w;
  final double h;

  const Detection({
    required this.label,
    required this.score,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  @override
  String toString() =>
      'Detection(label: $label, score: ${(score * 100).toStringAsFixed(1)}%, '
      'x: $x, y: $y, w: $w, h: $h)';
}

class PostProcessor {
  static const double _confidenceThreshold = 0.75;

  static List<Detection> decode(Map<String, dynamic> output) {
    final boxes = output["boxes"][0] as List;
    final classes = output["classes"][0] as List;
    final scores = output["scores"][0] as List;
    final count = (output["count"][0] as num).toInt();

    final List<Detection> results = [];

    for (int i = 0; i < count; i++) {
      final double score = (scores[i] as num).toDouble();

      // Skip detections below confidence threshold (< 75%)
      if (score < _confidenceThreshold) continue;

      final box = boxes[i] as List;
      final classId = (classes[i] as num).toInt();

      final double yMin = (box[0] as num).toDouble();
      final double xMin = (box[1] as num).toDouble();
      final double yMax = (box[2] as num).toDouble();
      final double xMax = (box[3] as num).toDouble();

      results.add(
        Detection(
          label: Labels.get(classId),
          score: score,
          x: xMin,
          y: yMin,
          w: xMax - xMin,
          h: yMax - yMin,
        ),
      );
    }

    // Sort by confidence descending (highest confidence first)
    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }
}
