import '../ml/spatial_analyzer.dart'; // ✅ SpatialObject is defined here

class ObjectMemory {
  final Map<String, _MemoryEntry> _seen = {};
  static const Duration _expiry = Duration(seconds: 8);
  static const Duration _suppressRepeat = Duration(seconds: 12);

  void update(List<SpatialObject> objects) {
    final now = DateTime.now();

    // Mark all as unseen first
    for (final e in _seen.values) e.active = false;

    for (final obj in objects) {
      final key = '${obj.label}_${obj.zone}';
      if (_seen.containsKey(key)) {
        _seen[key]!
          ..lastSeen = now
          ..active = true
          ..score = obj.score;
      } else {
        _seen[key] = _MemoryEntry(obj: obj, firstSeen: now, lastSeen: now);
      }
    }

    // Expire old entries
    _seen.removeWhere((_, e) => now.difference(e.lastSeen) > _expiry);
  }

  /// Returns only NEW objects not recently spoken about
  List<SpatialObject> newObjects() {
    final now = DateTime.now();
    return _seen.values
        .where(
          (e) =>
              e.active &&
              now.difference(e.lastSpoken ?? DateTime(2000)) > _suppressRepeat,
        )
        .map((e) => e.obj)
        .toList();
  }

  void markSpoken(List<SpatialObject> objects) {
    final now = DateTime.now();
    for (final obj in objects) {
      final key = '${obj.label}_${obj.zone}';
      if (_seen.containsKey(key)) _seen[key]!.lastSpoken = now;
    }
  }

  List<SpatialObject> get currentObjects =>
      _seen.values.where((e) => e.active).map((e) => e.obj).toList();

  void clear() => _seen.clear();
}

class _MemoryEntry {
  SpatialObject obj;
  DateTime firstSeen;
  DateTime lastSeen;
  DateTime? lastSpoken;
  bool active = true;
  double score;

  _MemoryEntry({
    required this.obj,
    required this.firstSeen,
    required this.lastSeen,
  }) : score = obj.score;
}
