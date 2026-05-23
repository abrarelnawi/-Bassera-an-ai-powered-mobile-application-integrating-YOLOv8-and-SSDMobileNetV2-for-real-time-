import 'package:flutter/material.dart';

class OverlayPainter extends StatelessWidget {
  final List<dynamic> recognitions;

  const OverlayPainter(this.recognitions, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: recognitions.map((rec) {
        final rect = rec["rect"];

        return Positioned(
          left: rect["x"] * MediaQuery.of(context).size.width,
          top: rect["y"] * MediaQuery.of(context).size.height,
          width: rect["w"] * MediaQuery.of(context).size.width,
          height: rect["h"] * MediaQuery.of(context).size.height,

          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Text(
              "${rec["detectedClass"]} ${(rec["confidenceInClass"] * 100).toStringAsFixed(0)}%",
              style: const TextStyle(
                color: Colors.red,
                backgroundColor: Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
