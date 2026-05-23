import 'labels.dart';

class Detection {
  final String label;
  final double score;
  final double x;
  final double y;
  final double w;
  final double h;

  Detection({
    required this.label,
    required this.score,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class PostProcessor {
  static List<Detection> decode(Map output) {
    final boxes = output["boxes"][0];
    final classes = output["classes"][0];
    final scores = output["scores"][0];
    final count = output["count"][0].toInt();

    List<Detection> results = [];

    for (int i = 0; i < count; i++) {
      final score = scores[i];

      // lower threshold first for debugging
      if (score > 0.4) {
        final box = boxes[i];

        final classId = classes[i].toInt();

        results.add(
          Detection(
            label: Labels.get(classId), // 🔥 THIS FIXES YOUR PROBLEM
            score: score,

            // SSD format: ymin, xmin, ymax, xmax
            y: box[0],
            x: box[1],
            w: box[3] - box[1],
            h: box[2] - box[0],
          ),
        );
      }
    }

    return results;
  }
}
