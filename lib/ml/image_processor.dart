import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  static const int _modelSize = 300;

  static Uint8List convert(CameraImage image) {
    // 1. Convert YUV → RGB
    img.Image rgb = _convertYUV(image);

    // 2. Sharpen before resize (more detail preserved)
    rgb = img.convolution(rgb, filter: _sharpenKernel, div: 1, offset: 0);

    // 3. Resize to model input size with cubic interpolation
    final img.Image resized = img.copyResize(
      rgb,
      width: _modelSize,
      height: _modelSize,
      interpolation: img.Interpolation.cubic,
    );

    // 4. Normalize to RGB bytes
    final Uint8List buffer = Uint8List(_modelSize * _modelSize * 3);
    int index = 0;

    for (int y = 0; y < _modelSize; y++) {
      for (int x = 0; x < _modelSize; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[index++] = pixel.r.toInt().clamp(0, 255);
        buffer[index++] = pixel.g.toInt().clamp(0, 255);
        buffer[index++] = pixel.b.toInt().clamp(0, 255);
      }
    }

    return buffer;
  }

  // Sharpening convolution kernel
  static const List<int> _sharpenKernel = [0, -1, 0, -1, 5, -1, 0, -1, 0];

  static img.Image _convertYUV(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image out = img.Image(width: width, height: height);

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final int yIndex = row * image.planes[0].bytesPerRow + col;

        // ✅ Use actual strides instead of assuming layout
        final int uvIndex =
            (row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride;

        final int Y = yPlane[yIndex];
        final int U = uPlane[uvIndex];
        final int V = vPlane[uvIndex];

        // BT.601 YUV → RGB (standard for camera)
        final int c = Y - 16;
        final int d = U - 128;
        final int e = V - 128;

        final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        out.setPixelRgb(col, row, r, g, b);
      }
    }

    return out;
  }
}
