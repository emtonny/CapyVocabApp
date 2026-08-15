import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  Future<void> speak(String text) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.stop();
    await _flutterTts.speak(normalizedText);
  }
}
