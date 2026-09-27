import 'package:capy_vocab/core/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps supported chat languages to device TTS locales', () {
    expect(ttsLocaleForLanguageCode('en'), 'en-US');
    expect(ttsLocaleForLanguageCode('en-US'), 'en-US');
    expect(ttsLocaleForLanguageCode('vi'), 'vi-VN');
    expect(ttsLocaleForLanguageCode('vi-VN'), 'vi-VN');
  });

  test('rejects an unsupported speech language', () {
    expect(
      () => ttsLocaleForLanguageCode('fr'),
      throwsArgumentError,
    );
  });
}
