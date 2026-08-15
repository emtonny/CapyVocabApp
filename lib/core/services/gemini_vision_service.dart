import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

typedef AccessTokenProvider = String? Function();
typedef SupabaseRestUrlProvider = String Function();

const int maxGeminiVocabularyWords = 15;

abstract interface class VisionScanClient {
  Future<GeminiVisionResult> analyzeImageBytes(Uint8List compressedImageBytes);
}

/// Sends an already-compressed local image to the authenticated Vision Edge
/// Function and converts its 0-1000 boxes into normalized coordinates.
class GeminiVisionService implements VisionScanClient {
  GeminiVisionService({
    http.Client? httpClient,
    AccessTokenProvider? accessTokenProvider,
    SupabaseRestUrlProvider? supabaseRestUrlProvider,
    Uri? endpoint,
  })  : _httpClient = httpClient ?? http.Client(),
        _endpointOverride = endpoint,
        _supabaseRestUrlProvider = supabaseRestUrlProvider ??
            (() => Supabase.instance.client.rest.url),
        _accessTokenProvider = accessTokenProvider ??
            (() => SupabaseService.auth.currentSession?.accessToken);

  static const Duration requestTimeout = Duration(seconds: 90);

  final http.Client _httpClient;
  final Uri? _endpointOverride;
  final SupabaseRestUrlProvider _supabaseRestUrlProvider;
  final AccessTokenProvider _accessTokenProvider;

  Uri get _endpoint =>
      _endpointOverride ??
      Uri.parse('${_supabaseRestUrlProvider()}/').resolve(
        '../../functions/v1/gemini-vision-scan',
      );

  @override
  Future<GeminiVisionResult> analyzeImageBytes(
    Uint8List compressedImageBytes,
  ) {
    return analyzeBase64Image(base64Encode(compressedImageBytes));
  }

  Future<GeminiVisionResult> analyzeBase64Image(String imageBase64) async {
    final accessToken = _accessTokenProvider()?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw const GeminiAuthenticationException(
        'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
      );
    }

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({'image_base64': imageBase64}),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const GeminiTimeoutException('Quá thời gian chờ, thử lại');
    } on http.ClientException catch (error) {
      throw GeminiApiException(
        0,
        'Đã có lỗi, thử lại',
        error.toString(),
      );
    }

    return _parseResponse(response);
  }

  GeminiVisionResult _parseResponse(http.Response response) {
    final decodedBody = _decodeResponseBody(response);

    if (response.statusCode == 200) {
      try {
        return GeminiVisionResult.fromJson(decodedBody);
      } on Object catch (error) {
        throw GeminiInvalidResponseException(
          'Không nhận diện được, thử ảnh khác',
          response.body,
          error,
        );
      }
    }

    final errorCode = _readErrorCode(decodedBody);
    switch (response.statusCode) {
      case 401:
      case 403:
        throw GeminiAuthenticationException(
          'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
          statusCode: response.statusCode,
          errorCode: errorCode,
        );
      case 413:
        throw GeminiImageTooLargeException(
          'Ảnh quá lớn, vui lòng chọn ảnh khác',
          errorCode: errorCode,
        );
      case 422:
        throw GeminiRecognitionException(
          'Không nhận diện được, thử ảnh khác',
          errorCode: errorCode,
        );
      case 429:
        throw GeminiQuotaException(
          'Hệ thống đang bận, thử lại sau',
          errorCode: errorCode,
        );
      case 504:
        throw GeminiTimeoutException(
          'Quá thời gian chờ, thử lại',
          errorCode: errorCode,
        );
      case 503:
        throw GeminiUnavailableException(
          'Dịch vụ Gemini đang tạm thời không khả dụng, vui lòng thử lại sau.',
          errorCode: errorCode,
          upstreamStatus: decodedBody['upstream_status'] is int
              ? decodedBody['upstream_status'] as int
              : null,
          scanId: decodedBody['scan_id'] is String
              ? decodedBody['scan_id'] as String
              : null,
        );
      case 500:
      case 502:
        throw GeminiApiException(
          response.statusCode,
          'Đã có lỗi, thử lại',
          response.body,
          errorCode: errorCode,
        );
      default:
        throw GeminiApiException(
          response.statusCode,
          'Đã có lỗi, thử lại',
          response.body,
          errorCode: errorCode,
        );
    }
  }

  Map<String, dynamic> _decodeResponseBody(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  String? _readErrorCode(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is String) return error;
    if (error is Map<String, dynamic>) {
      return error['code']?.toString();
    }
    return null;
  }
}

class GeminiVisionResult {
  const GeminiVisionResult({
    required this.detectedVocabulary,
    this.sceneDetections = const [],
    this.imageLanguage = 'en',
    this.confidence = 0.0,
  });

  factory GeminiVisionResult.empty() => const GeminiVisionResult(
        detectedVocabulary: [],
        imageLanguage: 'unknown',
      );

  factory GeminiVisionResult.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'];
    if (rawWords is! List<dynamic>) {
      throw const FormatException('Response field "words" must be a list.');
    }

    final parsedWords = _parseDetectionList(rawWords);
    final rawSceneWords = json['scene_words'];
    final sceneDetections = rawSceneWords is List<dynamic>
        ? _parseDetectionList(rawSceneWords)
        : parsedWords;

    return GeminiVisionResult(
      detectedVocabulary: rankDetectionsByBoxArea(
        keepLargestDetectionPerWord(parsedWords),
      ).take(maxGeminiVocabularyWords).toList(growable: false),
      sceneDetections: sceneDetections,
    );
  }

  final List<VocabDetection> detectedVocabulary;
  final List<VocabDetection> sceneDetections;
  final String imageLanguage;
  final double confidence;

  List<VocabDetection> get words => detectedVocabulary;
  List<VocabDetection> get placementContext =>
      sceneDetections.isEmpty ? detectedVocabulary : sceneDetections;

  Map<String, dynamic> toJson() => {
        'words': detectedVocabulary.map((word) => word.toJson()).toList(),
        'scene_words': placementContext.map((word) => word.toJson()).toList(),
      };
}

List<VocabDetection> _parseDetectionList(List<dynamic> rawWords) {
  return rawWords.map((rawWord) {
    if (rawWord is! Map<String, dynamic>) {
      throw const FormatException('Each word must be a JSON object.');
    }
    return VocabDetection.fromJson(rawWord);
  }).toList(growable: false);
}

List<VocabDetection> keepLargestDetectionPerWord(
  Iterable<VocabDetection> detections,
) {
  final order = <String>[];
  final largestByWord = <String, VocabDetection>{};

  for (final detection in detections) {
    final normalizedWord = detection.word.trim().toLowerCase();
    final current = largestByWord[normalizedWord];
    if (current == null) {
      order.add(normalizedWord);
      largestByWord[normalizedWord] = detection;
      continue;
    }
    if (detection.w * detection.h > current.w * current.h) {
      largestByWord[normalizedWord] = detection;
    }
  }

  return List.unmodifiable(order.map((word) => largestByWord[word]!));
}

List<VocabDetection> rankDetectionsByBoxArea(
  Iterable<VocabDetection> detections,
) {
  final ranked = detections.toList(growable: false)
    ..sort((first, second) {
      final byArea = (second.w * second.h).compareTo(first.w * first.h);
      if (byArea != 0) return byArea;

      final byWord = first.word
          .trim()
          .toLowerCase()
          .compareTo(second.word.trim().toLowerCase());
      if (byWord != 0) return byWord;
      return first.word.compareTo(second.word);
    });
  return List.unmodifiable(ranked);
}

class VocabDetection {
  const VocabDetection({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.partOfSpeech = '',
  });

  factory VocabDetection.fromJson(Map<String, dynamic> json) {
    final rawBox = json['box'];
    if (rawBox is! Map<String, dynamic>) {
      throw const FormatException('Word field "box" must be an object.');
    }

    final word = json['word'];
    final phonetic = json['phonetic'];
    final meaning = json['meaning_vi'];
    if (word is! String || phonetic is! String || meaning is! String) {
      throw const FormatException(
        'word, phonetic, and meaning_vi must be strings.',
      );
    }

    final x = _readCoordinate(rawBox, 'x');
    final y = _readCoordinate(rawBox, 'y');
    final width = _readCoordinate(rawBox, 'w');
    final height = _readCoordinate(rawBox, 'h');
    if (x + width > 1000 || y + height > 1000) {
      throw const FormatException(
        'Word box must stay within the 0-1000 image bounds.',
      );
    }

    return VocabDetection(
      word: word,
      phonetic: phonetic,
      meaning: meaning,
      x: x / 1000.0,
      y: y / 1000.0,
      w: width / 1000.0,
      h: height / 1000.0,
    );
  }

  final String word;
  final String phonetic;
  final String meaning;
  final String partOfSpeech;
  final double x;
  final double y;
  final double w;
  final double h;

  String get meaningVi => meaning;

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'meaning_vi': meaning,
        'box': {
          'x': (x * 1000).round(),
          'y': (y * 1000).round(),
          'w': (w * 1000).round(),
          'h': (h * 1000).round(),
        },
      };

  static int _readCoordinate(Map<String, dynamic> box, String key) {
    final value = box[key];
    if (value is! int || value < 0 || value > 1000) {
      throw FormatException('box.$key must be an integer from 0 to 1000.');
    }
    return value;
  }
}

abstract interface class GeminiVisionException implements Exception {
  String get message;
}

class GeminiAuthenticationException implements GeminiVisionException {
  const GeminiAuthenticationException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  @override
  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => 'GeminiAuthenticationException: $message';
}

class GeminiTimeoutException implements GeminiVisionException {
  const GeminiTimeoutException(this.message, {this.errorCode});

  @override
  final String message;
  final String? errorCode;

  @override
  String toString() => 'GeminiTimeoutException: $message';
}

class GeminiQuotaException implements GeminiVisionException {
  const GeminiQuotaException(this.message, {this.errorCode});

  @override
  final String message;
  final String? errorCode;

  @override
  String toString() => 'GeminiQuotaException: $message';
}

class GeminiUnavailableException implements GeminiVisionException {
  const GeminiUnavailableException(
    this.message, {
    this.errorCode,
    this.upstreamStatus,
    this.scanId,
  });

  @override
  final String message;
  final String? errorCode;
  final int? upstreamStatus;
  final String? scanId;

  @override
  String toString() {
    return 'GeminiUnavailableException['
        'code=$errorCode, upstreamStatus=$upstreamStatus, scanId=$scanId'
        ']: $message';
  }
}

class GeminiRecognitionException implements GeminiVisionException {
  const GeminiRecognitionException(this.message, {this.errorCode});

  @override
  final String message;
  final String? errorCode;

  @override
  String toString() => 'GeminiRecognitionException: $message';
}

class GeminiImageTooLargeException implements GeminiVisionException {
  const GeminiImageTooLargeException(this.message, {this.errorCode});

  @override
  final String message;
  final String? errorCode;

  @override
  String toString() => 'GeminiImageTooLargeException: $message';
}

class GeminiInvalidResponseException implements GeminiVisionException {
  const GeminiInvalidResponseException(
    this.message,
    this.rawBody,
    this.cause,
  );

  @override
  final String message;
  final String rawBody;
  final Object cause;

  @override
  String toString() => 'GeminiInvalidResponseException: $message';
}

class GeminiApiException implements GeminiVisionException {
  const GeminiApiException(
    this.statusCode,
    this.message,
    this.rawBody, {
    this.errorCode,
  });

  final int statusCode;
  @override
  final String message;
  final String rawBody;
  final String? errorCode;

  @override
  String toString() {
    final codeSuffix = errorCode == null ? '' : ', code=$errorCode';
    return 'GeminiApiException[$statusCode$codeSuffix]: $message';
  }
}
