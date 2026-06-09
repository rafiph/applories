import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

class VisionService {
  late final GenerativeModel _model;

  VisionService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    );
  }

  Future<Map<String, dynamic>> analyzeFoodImage(Uint8List imageBytes) async {
    try {
      final compressedBytes = _compressImage(imageBytes);

      final imagePart = DataPart('image/jpeg', compressedBytes);

      final prompt = TextPart(
        '''Analyze this food image and provide:
1. The name of the food/dish
2. An estimated calorie count for a typical serving

Respond ONLY in this exact JSON format, nothing else:
{
  "foodName": "name of the food",
  "calories": estimated_calorie_count
}

Be accurate with calorie estimates based on typical serving sizes.''',
      );

      final response = await _model.generateContent(
        [
          Content.multi([prompt, imagePart])
        ],
      );

      final text = response.text ?? '';

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('Invalid response format from API');
      }

      final jsonString = jsonMatch.group(0)!;
      final foodNameMatch = RegExp(r'"foodName"\s*:\s*"([^"]+)"').firstMatch(jsonString);
      final caloriesMatch = RegExp(r'"calories"\s*:\s*(\d+)').firstMatch(jsonString);

      if (foodNameMatch == null || caloriesMatch == null) {
        throw Exception('Could not extract food info from response');
      }

      return {
        'foodName': foodNameMatch.group(1) ?? 'Unknown',
        'calories': int.parse(caloriesMatch.group(1) ?? '0'),
      };
    } catch (e) {
      print('Error analyzing food image: $e');
      rethrow;
    }
  }

  Uint8List _compressImage(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      final resized = image.width > 1024
          ? img.copyResize(image, width: 1024, height: (image.height * 1024 ~/ image.width))
          : image;

      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      print('Image compression failed, using original: $e');
      return imageBytes;
    }
  }
}
