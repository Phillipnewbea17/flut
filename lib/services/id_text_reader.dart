import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/id_text_parser.dart';

/// Reads the text on a photo of an ID. Done on the phone (Google ML Kit's
/// on-device text recognition): the photo is not sent anywhere.
abstract class IdTextReader {
  Future<IdExtraction> read(String imagePath);
}

class MlKitIdTextReader implements IdTextReader {
  @override
  Future<IdExtraction> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return IdTextParser.parse(result.text);
    } finally {
      await recognizer.close();
    }
  }
}
