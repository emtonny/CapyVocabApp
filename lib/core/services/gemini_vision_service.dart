import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

/// Service tương tác với Gemini 1.5 Flash API để phân tích ảnh (AI Scan).
///
/// Luồng chuẩn:
///   1. Nhận File ảnh gốc từ Camera / Gallery
///   2. Nén về JPEG tối đa 1024×1024 px, dung lượng < 300 KB
///   3. Mã hóa Base64 → gửi POST lên Gemini endpoint
///   4. Parse JSON response chứa danh sách từ vựng + tọa độ tương đối (x, y, w, h)
///
/// Xử lý lỗi:
///   - Timeout 12 giây → ném [GeminiTimeoutException]
///   - HTTP 429 (hết quota) → ném [GeminiQuotaException]
///   - HTTP khác 200 → ném [GeminiApiException]
class GeminiVisionService {
  final http.Client _httpClient;

  /// Endpoint Gemini 1.5 Flash (generateContent)
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Timeout mỗi request API
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// Ngưỡng dung lượng ảnh tối đa gửi Gemini (300 KB)
  static const int _maxImageBytes = 300 * 1024;

  GeminiVisionService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Phân tích [imageFile]: nén ảnh → gửi Gemini → trả về JSON kết quả.
  ///
  /// Throws:
  ///   [GeminiTimeoutException] — nếu request vượt quá 12 giây
  ///   [GeminiQuotaException]   — nếu server trả HTTP 429
  ///   [GeminiApiException]     — nếu server trả mã lỗi khác
  Future<GeminiVisionResult> analyzeImage(File imageFile) async {
    final Uint8List compressed = await _compressImage(imageFile);
    final String base64Image = base64Encode(compressed);
    return _callGeminiApi(base64Image);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Nén ảnh về JPEG tối đa 1024×1024 px, dung lượng < 300 KB.
  Future<Uint8List> _compressImage(File imageFile) async {
    Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 512,
      minHeight: 512,
      quality: 85,
      format: CompressFormat.jpeg,
    );

    // Nếu vẫn > 300 KB, giảm quality xuống 60
    if (compressed != null && compressed.length > _maxImageBytes) {
      compressed = await FlutterImageCompress.compressWithList(
        compressed,
        quality: 60,
        format: CompressFormat.jpeg,
      );
    }

    return compressed ?? await imageFile.readAsBytes();
  }

  /// Gọi Gemini 1.5 Flash API với ảnh Base64 đã nén.
  Future<GeminiVisionResult> _callGeminiApi(String base64Image) async {
    final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final Uri url = Uri.parse('$_geminiBaseUrl?key=$apiKey');

    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image,
              }
            },
            {
              'text': '''Analyze the English vocabulary in this image.
Return a JSON object with this exact structure (no markdown, raw JSON only):
{
  "detected_vocabulary": [
    {
      "word": "example",
      "phonetic": "/ɪɡˈzæmpəl/",
      "meaning": "ví dụ (tiếng Việt)",
      "part_of_speech": "noun",
      "bounding_box": { "x": 0.10, "y": 0.20, "w": 0.15, "h": 0.05 }
    }
  ],
  "image_language": "en",
  "confidence": 0.95
}
Coordinates x, y, w, h are relative to image size (0.0 to 1.0).
If no English words found, return an empty detected_vocabulary array.'''
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      }
    };

    http.Response response;
    try {
      response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(requestBody),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw GeminiTimeoutException(
        'Gemini không phản hồi sau ${_requestTimeout.inSeconds} giây. '
        'Kiểm tra kết nối mạng và thử lại.',
      );
    }

    return _parseResponse(response);
  }

  GeminiVisionResult _parseResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          // Gemini trả về trong candidates[0].content.parts[0].text
          final candidates = body['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            return GeminiVisionResult.empty();
          }
          final text = (candidates.first as Map<String, dynamic>)['content']
              ['parts'][0]['text'] as String;
          final parsed = jsonDecode(text) as Map<String, dynamic>;
          return GeminiVisionResult.fromJson(parsed);
        } catch (e) {
          debugPrint('GeminiVisionService: parse error — $e');
          return GeminiVisionResult.empty();
        }

      case 429:
        throw GeminiQuotaException(
          'Hệ thống AI đang bận. Nâng cấp PRO để quét không giới hạn.',
        );

      case 400:
        throw GeminiApiException(
          400,
          'Ảnh không hợp lệ, hãy chụp lại.',
          response.body,
        );

      case 500:
      case 503:
        throw GeminiApiException(
          response.statusCode,
          'Dịch vụ AI tạm thời gián đoạn, thử lại sau.',
          response.body,
        );

      default:
        throw GeminiApiException(
          response.statusCode,
          'Gemini 1.5 Flash API Error [${response.statusCode}]',
          response.body,
        );
    }
  }
}

// ── Result model ──────────────────────────────────────────────────────────────

/// Kết quả từ Gemini Vision API.
class GeminiVisionResult {
  final List<VocabDetection> detectedVocabulary;
  final String imageLanguage;
  final double confidence;

  const GeminiVisionResult({
    required this.detectedVocabulary,
    required this.imageLanguage,
    required this.confidence,
  });

  factory GeminiVisionResult.empty() => const GeminiVisionResult(
        detectedVocabulary: [],
        imageLanguage: 'unknown',
        confidence: 0.0,
      );

  factory GeminiVisionResult.fromJson(Map<String, dynamic> json) {
    final rawList =
        (json['detected_vocabulary'] as List<dynamic>?) ?? [];
    return GeminiVisionResult(
      detectedVocabulary: rawList
          .map((e) => VocabDetection.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageLanguage: json['image_language']?.toString() ?? 'en',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Một từ vựng nhận diện được kèm tọa độ tương đối trên ảnh.
class VocabDetection {
  final String word;
  final String phonetic;
  final String meaning;
  final String partOfSpeech;

  /// Tọa độ tương đối (0.0–1.0) so với kích thước ảnh gốc
  final double x;
  final double y;
  final double w;
  final double h;

  const VocabDetection({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.partOfSpeech,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory VocabDetection.fromJson(Map<String, dynamic> json) {
    final bbox =
        (json['bounding_box'] as Map<String, dynamic>?) ?? {};
    return VocabDetection(
      word: json['word']?.toString() ?? '',
      phonetic: json['phonetic']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      partOfSpeech: json['part_of_speech']?.toString() ?? '',
      x: (bbox['x'] as num?)?.toDouble() ?? 0.0,
      y: (bbox['y'] as num?)?.toDouble() ?? 0.0,
      w: (bbox['w'] as num?)?.toDouble() ?? 0.0,
      h: (bbox['h'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'meaning': meaning,
        'part_of_speech': partOfSpeech,
        'bounding_box': {'x': x, 'y': y, 'w': w, 'h': h},
      };
}

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Gemini không phản hồi trong thời gian timeout.
class GeminiTimeoutException implements Exception {
  final String message;
  const GeminiTimeoutException(this.message);
  @override
  String toString() => 'GeminiTimeoutException: $message';
}

/// Gemini trả về HTTP 429 — hết quota, cần nâng cấp PRO.
class GeminiQuotaException implements Exception {
  final String message;
  const GeminiQuotaException(this.message);
  @override
  String toString() => 'GeminiQuotaException: $message';
}

/// Gemini trả về lỗi HTTP khác (400, 500, ...).
class GeminiApiException implements Exception {
  final int statusCode;
  final String message;
  final String rawBody;
  const GeminiApiException(this.statusCode, this.message, this.rawBody);
  @override
  String toString() => 'GeminiApiException[$statusCode]: $message';
}
