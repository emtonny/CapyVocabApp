import 'dart:convert';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _testEndpoint = Uri.parse(
  'https://test-project.supabase.co/functions/v1/gemini-vision-scan',
);

void main() {
  test('timeout client đủ dài để Edge Function thử toàn bộ model chain', () {
    expect(GeminiVisionService.requestTimeout, const Duration(seconds: 90));
  });

  test('endpoint mặc định dùng đúng project host từ Supabase runtime',
      () async {
    late Uri capturedUrl;
    final service = GeminiVisionService(
      httpClient: MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(jsonEncode({'words': []}), 200);
      }),
      accessTokenProvider: () => 'valid-user-jwt',
      supabaseRestUrlProvider: () =>
          'https://configured-project.supabase.co/rest/v1',
    );

    await service.analyzeBase64Image('compressed-base64');

    expect(
      capturedUrl,
      Uri.parse(
        'https://configured-project.supabase.co/functions/v1/'
        'gemini-vision-scan',
      ),
    );
  });

  test('gửi JWT, base64 và chuẩn hóa box 0-1000', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'words': [
            {
              'number': 1,
              'word': 'apple',
              'phonetic': '/ˈæp.əl/',
              'meaning_vi': 'quả táo',
              'box': {'x': 125, 'y': 250, 'w': 500, 'h': 100},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = GeminiVisionService(
      httpClient: client,
      accessTokenProvider: () => 'valid-user-jwt',
      endpoint: _testEndpoint,
    );

    final result = await service.analyzeBase64Image('compressed-base64');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url, _testEndpoint);
    expect(
      capturedRequest.headers['authorization'],
      'Bearer valid-user-jwt',
    );
    expect(
      jsonDecode(capturedRequest.body),
      {'image_base64': 'compressed-base64'},
    );
    expect(result.words, hasLength(1));
    expect(result.words.single.number, 1);
    expect(result.words.single.word, 'apple');
    expect(result.words.single.numberedWord, '1. apple');
    expect(result.words.single.meaningVi, 'quả táo');
    expect(result.words.single.x, 0.125);
    expect(result.words.single.y, 0.25);
    expect(result.words.single.w, 0.5);
    expect(result.words.single.h, 0.1);
    expect(
      result.toJson()['words'],
      [
        {
          'number': 1,
          'word': 'apple',
          'phonetic': '/ˈæp.əl/',
          'meaning_vi': 'quả táo',
          'box': {'x': 125, 'y': 250, 'w': 500, 'h': 100},
        },
      ],
    );
    expect(result.toJson()['scene_words'], result.toJson()['words']);
  });

  test('trùng word chỉ giữ box riêng lẻ lớn nhất và bảo toàn scene context',
      () {
    final result = GeminiVisionResult.fromJson({
      'words': [
        {
          'word': 'apple',
          'phonetic': '/ˈæpl/',
          'meaning_vi': 'quả táo',
          'box': {'x': 62, 'y': 631, 'w': 109, 'h': 189},
        },
        {
          'word': ' Apple ',
          'phonetic': '/ˈæpl/',
          'meaning_vi': 'quả táo',
          'box': {'x': 500, 'y': 365, 'w': 117, 'h': 185},
        },
        {
          'word': 'apple',
          'phonetic': '/ˈæpl/',
          'meaning_vi': 'quả táo',
          'box': {'x': 609, 'y': 441, 'w': 113, 'h': 113},
        },
        {
          'word': 'leaf',
          'phonetic': '/liːf/',
          'meaning_vi': 'chiếc lá',
          'box': {'x': 324, 'y': 144, 'w': 334, 'h': 340},
        },
      ],
    });

    expect(result.sceneDetections, hasLength(4));
    expect(result.words, hasLength(2));
    expect(result.words.first.word, 'leaf');
    final apple = result.words.last;
    expect(apple.word, ' Apple ');
    expect(apple.x, 0.5);
    expect(apple.y, 0.365);
    expect(apple.w, 0.117);
    expect(apple.h, 0.185);
  });

  test('top 15 luôn giữ object có diện tích lớn nhất bất kể response order',
      () {
    Map<String, dynamic> word(int index) => {
          'word': 'object-$index',
          'phonetic': '/object/',
          'meaning_vi': 'vật thể $index',
          'box': {'x': 0, 'y': 0, 'w': 10 + index, 'h': 10},
        };
    final responseOrder = List.generate(17, word);

    final result = GeminiVisionResult.fromJson({'words': responseOrder});
    final reversed = GeminiVisionResult.fromJson({
      'words': responseOrder.reversed.toList(),
    });

    expect(result.words, hasLength(maxGeminiVocabularyWords));
    expect(
      result.words.map((detection) => detection.word),
      reversed.words.map((detection) => detection.word),
    );
    expect(result.sceneDetections, hasLength(17));
    final keptAreas = result.words
        .map((detection) => detection.w * detection.h)
        .toList(growable: false);
    for (var index = 1; index < keptAreas.length; index++) {
      expect(keptAreas[index - 1], greaterThanOrEqualTo(keptAreas[index]));
    }
    expect(result.words.map((word) => word.word), isNot(contains('object-0')));
    expect(result.words.map((word) => word.word), isNot(contains('object-1')));
  });

  test('response cũ thiếu number được đánh số lại sau khi xếp hạng', () {
    final result = GeminiVisionResult.fromJson({
      'words': [
        {
          'word': 'apple',
          'phonetic': '/ˈæp.əl/',
          'meaning_vi': 'quả táo',
          'box': {'x': 100, 'y': 100, 'w': 100, 'h': 100},
        },
        {
          'word': 'desk lamp',
          'phonetic': '/desk læmp/',
          'meaning_vi': 'đèn bàn',
          'box': {'x': 300, 'y': 100, 'w': 100, 'h': 200},
        },
      ],
    });

    expect(result.words.map((word) => word.number), [1, 2]);
    expect(result.toJson()['words'], [
      {
        'number': 1,
        'word': 'desk lamp',
        'phonetic': '/desk læmp/',
        'meaning_vi': 'đèn bàn',
        'box': {'x': 300, 'y': 100, 'w': 100, 'h': 200},
      },
      {
        'number': 2,
        'word': 'apple',
        'phonetic': '/ˈæp.əl/',
        'meaning_vi': 'quả táo',
        'box': {'x': 100, 'y': 100, 'w': 100, 'h': 100},
      },
    ]);
  });

  test('không gửi request khi không có access token', () async {
    var requestCount = 0;
    final service = GeminiVisionService(
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
      accessTokenProvider: () => null,
      endpoint: _testEndpoint,
    );

    await expectLater(
      service.analyzeBase64Image('image'),
      throwsA(
        isA<GeminiAuthenticationException>().having(
          (error) => error.message,
          'message',
          'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
        ),
      ),
    );
    expect(requestCount, 0);
  });

  final errorCases = <({
    int status,
    String code,
    Type type,
    String message,
  })>[
    (
      status: 429,
      code: 'quota_exceeded',
      type: GeminiQuotaException,
      message: 'Hệ thống đang bận, thử lại sau',
    ),
    (
      status: 422,
      code: 'truncated_response',
      type: GeminiRecognitionException,
      message: 'Không nhận diện được, thử ảnh khác',
    ),
    (
      status: 422,
      code: 'empty_response',
      type: GeminiRecognitionException,
      message: 'Không nhận diện được, thử ảnh khác',
    ),
    (
      status: 504,
      code: 'timeout',
      type: GeminiTimeoutException,
      message: 'Quá thời gian chờ, thử lại',
    ),
    (
      status: 413,
      code: 'image_too_large',
      type: GeminiImageTooLargeException,
      message: 'Ảnh quá lớn, vui lòng chọn ảnh khác',
    ),
    (
      status: 500,
      code: 'internal_error',
      type: GeminiApiException,
      message: 'Đã có lỗi, thử lại',
    ),
    (
      status: 502,
      code: 'upstream_error',
      type: GeminiApiException,
      message: 'Đã có lỗi, thử lại',
    ),
    (
      status: 503,
      code: 'upstream_unavailable',
      type: GeminiUnavailableException,
      message:
          'Dịch vụ Gemini đang tạm thời không khả dụng, vui lòng thử lại sau.',
    ),
  ];

  for (final errorCase in errorCases) {
    test(
      'HTTP ${errorCase.status} ${errorCase.code} được ánh xạ riêng',
      () async {
        final service = GeminiVisionService(
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'error': errorCase.code,
                if (errorCase.status == 503) ...{
                  'upstream_status': 503,
                  'scan_id': 'scan-503',
                },
              }),
              errorCase.status,
            ),
          ),
          accessTokenProvider: () => 'valid-user-jwt',
          endpoint: _testEndpoint,
        );

        try {
          await service.analyzeBase64Image('image');
          fail('Expected a GeminiVisionException.');
        } catch (error) {
          expect(error.runtimeType, errorCase.type);
          expect((error as GeminiVisionException).message, errorCase.message);
          if (error is GeminiUnavailableException) {
            expect(error.errorCode, errorCase.code);
            expect(error.upstreamStatus, 503);
            expect(error.scanId, 'scan-503');
            expect(error.toString(), contains('upstreamStatus=503'));
            expect(error.toString(), contains('scanId=scan-503'));
          }
        }
      },
    );
  }

  test('response 200 sai schema không bị coi là thành công rỗng', () async {
    final service = GeminiVisionService(
      httpClient: MockClient(
        (request) async => http.Response(jsonEncode({'words': 'invalid'}), 200),
      ),
      accessTokenProvider: () => 'valid-user-jwt',
      endpoint: _testEndpoint,
    );

    await expectLater(
      service.analyzeBase64Image('image'),
      throwsA(isA<GeminiInvalidResponseException>()),
    );
  });

  test('bounding box chạm biên phải và dưới vẫn hợp lệ', () {
    final result = GeminiVisionResult.fromJson({
      'words': [
        {
          'word': 'edge',
          'phonetic': '/edʒ/',
          'meaning_vi': 'cạnh',
          'box': {'x': 750, 'y': 800, 'w': 250, 'h': 200},
        },
      ],
    });

    expect(result.words.single.x + result.words.single.w, 1.0);
    expect(result.words.single.y + result.words.single.h, 1.0);
  });

  final overflowingBoxes = <Map<String, int>>[
    {'x': 800, 'y': 100, 'w': 201, 'h': 100},
    {'x': 100, 'y': 900, 'w': 100, 'h': 101},
  ];

  for (final box in overflowingBoxes) {
    test('bounding box tràn biên ảnh bị từ chối: $box', () {
      expect(
        () => GeminiVisionResult.fromJson({
          'words': [
            {
              'word': 'overflow',
              'phonetic': '/ˌəʊvəˈfləʊ/',
              'meaning_vi': 'tràn',
              'box': box,
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Word box must stay within the 0-1000 image bounds.',
          ),
        ),
      );
    });
  }
}
