class VisionObject {
  final String id; // label + tracking hash
  String label;

  double x;
  double y;
  double w;
  double h;

  DateTime firstSeen;
  DateTime lastSeen;

  int stableFrames;

  VisionObject({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.firstSeen,
    required this.lastSeen,
    this.stableFrames = 1,
  });

  void update(double nx, double ny, double nw, double nh) {
    x = nx;
    y = ny;
    w = nw;
    h = nh;
    lastSeen = DateTime.now();
    stableFrames++;
  }

  double get area => w * h;
}
