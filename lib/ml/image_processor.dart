import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  static Uint8List convert(CameraImage image) {
    final img.Image rgb = _convertYUV(image);

    final img.Image resized = img.copyResize(rgb, width: 300, height: 300);

    final Uint8List buffer = Uint8List(300 * 300 * 3);

    int index = 0;

    for (int y = 0; y < 300; y++) {
      for (int x = 0; x < 300; x++) {
        final pixel = resized.getPixel(x, y);

        buffer[index++] = pixel.r.toInt();
        buffer[index++] = pixel.g.toInt();
        buffer[index++] = pixel.b.toInt();
      }
    }

    return buffer;
  }

  static img.Image _convertYUV(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final img.Image out = img.Image(width: width, height: height);

    final y = image.planes[0].bytes;
    final u = image.planes[1].bytes;
    final v = image.planes[2].bytes;

    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        final yIndex = i * width + j;
        final uvIndex = (i ~/ 2) * (width ~/ 2) + (j ~/ 2);

        final Y = y[yIndex];
        final U = u[uvIndex];
        final V = v[uvIndex];

        int r = (Y + 1.370705 * (V - 128)).toInt();
        int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).toInt();
        int b = (Y + 1.732446 * (U - 128)).toInt();

        out.setPixelRgb(
          j,
          i,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
        );
      }
    }

    return out;
  }
}
