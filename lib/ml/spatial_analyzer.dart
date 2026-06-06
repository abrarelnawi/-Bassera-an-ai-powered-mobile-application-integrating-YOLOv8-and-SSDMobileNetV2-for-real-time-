class SpatialObject {
  final String label;
  final double score;
  final String zone; // left / center / right
  final String distance; // near / mid / far
  final int priority; // 1=critical 2=important 3=neutral 4=ignore
  final bool isDanger;

  const SpatialObject({
    required this.label,
    required this.score,
    required this.zone,
    required this.distance,
    required this.priority,
    required this.isDanger,
  });

  double get urgencyScore => score * (5 - priority) * (isDanger ? 3 : 1);

  @override
  String toString() => '$label ($zone, $distance)';
}

class SpatialAnalyzer {
  // Priority 1 = critical danger
  static const _critical = {
    'car',
    'motorcycle',
    'bicycle',
    'truck',
    'bus',
    'stairs',
    'staircase',
    'step',
    'fire',
    'knife',
    'scissors',
    'gun',
    'hole',
    'pit',
    'pothole',
  };

  // Priority 2 = important
  static const _important = {
    'person',
    'dog',
    'cat',
    'door',
    'gate',
    'traffic light',
    'stop sign',
    'pole',
    'column',
    'bicycle',
    'scooter',
  };

  // Priority 3 = neutral
  static const _neutral = {
    'chair',
    'couch',
    'sofa',
    'table',
    'desk',
    'bench',
    'bed',
    'toilet',
    'sink',
    'refrigerator',
    'oven',
    'microwave',
    'tv',
    'laptop',
    'cup',
    'bottle',
  };

  // Priority 4 = ignore unless very close
  static const _ignore = {
    'vase',
    'plant',
    'clock',
    'picture',
    'painting',
    'book',
    'remote',
    'keyboard',
    'mouse',
    'phone',
  };

  static List<SpatialObject> analyze(List<dynamic> rawDetections) {
    final List<SpatialObject> result = [];

    for (final r in rawDetections) {
      final label = (r['detectedClass'] ?? 'unknown').toString().toLowerCase();
      final score = (r['confidenceInClass'] ?? 0).toDouble();
      final x = (r['rect']?['x'] ?? 0.5).toDouble();
      final w = (r['rect']?['w'] ?? 0.1).toDouble();
      final h = (r['rect']?['h'] ?? 0.1).toDouble();

      final priority = _getPriority(label);
      if (priority == 4 && score < 0.85) continue; // skip low-conf ignore-tier

      final zone = _getZone(x + w / 2);
      final distance = _getDistance(w, h);
      final isDanger = priority == 1;

      result.add(
        SpatialObject(
          label: label,
          score: score,
          zone: zone,
          distance: distance,
          priority: priority,
          isDanger: isDanger,
        ),
      );
    }

    // Sort by urgency: danger first, then priority, then score
    result.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return result;
  }

  static String _getZone(double cx) {
    if (cx < 0.33) return 'left';
    if (cx < 0.66) return 'center';
    return 'right';
  }

  static String _getDistance(double w, double h) {
    final area = w * h;
    if (area > 0.25) return 'near';
    if (area > 0.07) return 'mid';
    return 'far';
  }

  static int _getPriority(String label) {
    if (_critical.any((k) => label.contains(k))) return 1;
    if (_important.any((k) => label.contains(k))) return 2;
    if (_neutral.any((k) => label.contains(k))) return 3;
    return 4;
  }

  static bool hasDanger(List<SpatialObject> objects) =>
      objects.any((o) => o.isDanger && o.distance != 'far');

  static List<SpatialObject> dangerObjects(List<SpatialObject> objects) =>
      objects.where((o) => o.isDanger && o.distance != 'far').toList();
}
