import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetector {
  static const double _shakeThreshold = 18.0;
  static const int _requiredShakes = 2;
  static const Duration _shakeWindow = Duration(milliseconds: 1500);

  StreamSubscription? _subscription;
  int _shakeCount = 0;
  DateTime? _firstShakeTime;
  VoidCallback? _onDoubleShake;
  bool _onCooldown = false;

  void start(VoidCallback onDoubleShake) {
    _onDoubleShake = onDoubleShake;
    print("[ShakeDetector] Started listening");

    _subscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen((event) {
          final magnitude = _magnitude(event.x, event.y, event.z);

          if (magnitude > _shakeThreshold && !_onCooldown) {
            final now = DateTime.now();
            print(
              "[ShakeDetector] Shake! magnitude=$magnitude count=${_shakeCount + 1}",
            );

            if (_firstShakeTime == null) {
              _firstShakeTime = now;
              _shakeCount = 1;
            } else if (now.difference(_firstShakeTime!) <= _shakeWindow) {
              _shakeCount++;
              if (_shakeCount >= _requiredShakes) {
                print("[ShakeDetector] ✅ Double shake!");
                _reset();
                _onCooldown = true;
                _onDoubleShake?.call();
                Future.delayed(const Duration(seconds: 2), () {
                  _onCooldown = false;
                });
              }
            } else {
              _firstShakeTime = now;
              _shakeCount = 1;
            }
          }
        });
  }

  // ✅ added
  double _magnitude(double x, double y, double z) =>
      sqrt(x * x + y * y + z * z);

  void _reset() {
    _shakeCount = 0;
    _firstShakeTime = null;
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    print("[ShakeDetector] Stopped");
  }
}
