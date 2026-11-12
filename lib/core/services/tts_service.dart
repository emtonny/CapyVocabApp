import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  Future<void> speak(
    String text, {
    String languageCode = 'en',
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;

    await _flutterTts.setLanguage(ttsLocaleForLanguageCode(languageCode));
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.stop();
    await _flutterTts.speak(normalizedText);
  }

  Future<void> stop() => _flutterTts.stop();
}

String ttsLocaleForLanguageCode(String languageCode) {
  return switch (languageCode.trim().toLowerCase()) {
    'en' || 'en-us' => 'en-US',
    'vi' || 'vi-vn' => 'vi-VN',
    _ => throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Only Vietnamese and English speech are supported.',
      ),
  };
}
