import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service tương tác với Google Cloud Vision API
/// Hỗ trợ Label Detection, Text Detection (OCR) và Object Localization cho tính năng AI Scan.
class CloudVisionService {
  final String apiKey;
  final http.Client _httpClient;

  static const String _visionApiUrl =
      'https://vision.googleapis.com/v1/images:annotate';

  CloudVisionService({
    this.apiKey = 'YOUR_GOOGLE_CLOUD_VISION_API_KEY',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Gửi ảnh dưới dạng base64 lên Google Cloud Vision API để phân tích
  Future<Map<String, dynamic>> analyzeImage({
    required File imageFile,
    List<String> featureTypes = const [
      'LABEL_DETECTION',
      'TEXT_DETECTION',
      'OBJECT_LOCALIZATION',
    ],
    int maxResults = 10,
  }) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      return await analyzeBase64Image(
        base64Image: base64Image,
        featureTypes: featureTypes,
        maxResults: maxResults,
      );
    } catch (e) {
      debugPrint('Cloud Vision Service Error: $e');
      rethrow;
    }
  }

  /// Gửi chuỗi ảnh Base64 lên Cloud Vision REST API
  Future<Map<String, dynamic>> analyzeBase64Image({
    required String base64Image,
    List<String> featureTypes = const [
      'LABEL_DETECTION',
      'TEXT_DETECTION',
      'OBJECT_LOCALIZATION',
    ],
    int maxResults = 10,
  }) async {
    final Uri url = Uri.parse('$_visionApiUrl?key=$apiKey');

    final List<Map<String, dynamic>> features = featureTypes
        .map((type) => {
              'type': type,
              'maxResults': maxResults,
            })
        .toList();

    final Map<String, dynamic> requestBody = {
      'requests': [
        {
          'image': {'content': base64Image},
          'features': features,
        }
      ]
    };

    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final responses = data['responses'] as List<dynamic>?;
      if (responses != null && responses.isNotEmpty) {
        return responses.first as Map<String, dynamic>;
      }
      return {};
    } else {
      throw HttpException(
        'Google Cloud Vision API Error [${response.statusCode}]: ${response.body}',
      );
    }
  }

  /// Trích xuất danh sách nhãn từ kết quả API
  List<String> extractLabels(Map<String, dynamic> visionResponse) {
    final labelAnnotations =
        visionResponse['labelAnnotations'] as List<dynamic>?;
    if (labelAnnotations == null) return [];

    return labelAnnotations
        .map((item) => item['description']?.toString() ?? '')
        .where((label) => label.isNotEmpty)
        .toList();
  }

  /// Trích xuất văn bản nhận diện được (OCR)
  String extractText(Map<String, dynamic> visionResponse) {
    final textAnnotations =
        visionResponse['textAnnotations'] as List<dynamic>?;
    if (textAnnotations == null || textAnnotations.isEmpty) return '';
    return textAnnotations.first['description']?.toString() ?? '';
  }
}
