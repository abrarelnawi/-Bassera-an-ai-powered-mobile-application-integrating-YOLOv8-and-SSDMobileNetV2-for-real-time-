import 'package:tflite_v2/tflite_v2.dart';
import 'package:camera/camera.dart';

class TFLiteService {
  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: "assets/ssd_mobilenet.tflite",
      labels: "assets/ssd_mobilenet.txt",
    );

    print("Model loaded: $res");
  }

  Future<List<dynamic>?> detect(CameraImage image) async {
    return await Tflite.detectObjectOnFrame(
      bytesList: image.planes.map((p) => p.bytes).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      numResultsPerClass: 1,
      threshold: 0.4,
      asynch: true,
    );
  }

  Future<void> close() async {
    await Tflite.close();
  }
}
