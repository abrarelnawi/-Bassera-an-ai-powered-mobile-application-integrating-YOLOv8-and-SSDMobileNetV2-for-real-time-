import 'package:flutter/services.dart';

class Labels {
  static List<String> labels = [];

  static Future<void> load() async {
    final data = await rootBundle.loadString('assets/ssd_mobilenet.txt');
    labels = data.split('\n');
  }

  static String get(int index) {
    if (index < 0 || index >= labels.length) {
      return "unknown";
    }
    return labels[index];
  }
}
