import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraService {
  CameraController? controller;
  List<CameraDescription>? cameras;

  Future<void> init() async {
    print("📷 Getting available cameras...");

    cameras = await availableCameras();

    print("📷 Cameras found: ${cameras?.length}");

    if (cameras == null || cameras!.isEmpty) {
      throw Exception("No cameras found");
    }

    controller = CameraController(
      cameras!.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    print("📷 Initializing controller...");

    await controller!.initialize();

    print("📷 Camera controller initialized");
  }

  CameraController get controllerInstance {
    if (controller == null) {
      throw Exception("Camera not initialized");
    }
    return controller!;
  }

  Future<void> dispose() async {
    print("📷 Disposing camera...");
    await controller?.dispose();
  }
}
