import 'package:flutter/material.dart';

import '../camera/camera_service.dart';
import '../ml/tflite_service.dart';
import '../camera/camera_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CameraService _cameraService = CameraService();
  final TFLiteService _tfliteService = TFLiteService();

  bool isReady = false;
  String status = "Starting...";

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      print("🚀 INIT STARTED");

      setState(() => status = "Initializing camera...");

      // 1. CAMERA INIT
      await _cameraService.init();
      print("📷 Camera initialized");

      setState(() => status = "Loading model...");

      // 2. MODEL INIT
      await _tfliteService.loadModel();
      print("🧠 Model loaded");

      setState(() => status = "Starting stream...");

      // 3. IMPORTANT FIX: ensure stream is ready AFTER both init
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        isReady = true;
        status = "Ready";
      });

      print("✅ ALL READY");
    } catch (e, s) {
      print("❌ INIT ERROR: $e");
      print(s);

      setState(() {
        status = "ERROR: $e";
      });
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _tfliteService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(status, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CameraView(
        controller: _cameraService.controllerInstance,
        service: _tfliteService,
      ),
    );
  }
}
