import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../ml/tflite_service.dart';
import '../ui/overlay_painter.dart';

class CameraView extends StatefulWidget {
  final CameraController controller;
  final TFLiteService service;

  const CameraView({
    super.key,
    required this.controller,
    required this.service,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  List<dynamic>? recognitions;

  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.startImageStream(_runModel);
  }

  void _runModel(CameraImage image) async {
    if (isBusy) return;
    isBusy = true;

    try {
      final results = await widget.service.detect(image);

      if (mounted) {
        setState(() {
          recognitions = results;
        });
      }
    } catch (e) {
      print("Error: $e");
    }

    isBusy = false;
  }

  @override
  void dispose() {
    widget.controller.stopImageStream();
    widget.service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CameraPreview(widget.controller),

        if (recognitions != null) OverlayPainter(recognitions!),
      ],
    );
  }
}
