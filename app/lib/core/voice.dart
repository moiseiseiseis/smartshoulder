import 'package:flutter_tts/flutter_tts.dart';

/// Voz en español para guiar la sesión sin mirar el teléfono (contexto/07 §5.2).
class Voice {
  final FlutterTts _tts = FlutterTts();
  bool enabled;
  bool _ready = false;

  Voice({this.enabled = true});

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('es-MX');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      // Sin motor de voz: la sesión sigue funcionando en silencio.
    }
  }

  Future<void> say(String text, {bool interrupt = true}) async {
    if (!enabled) return;
    await _init();
    try {
      if (interrupt) await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

const _numbers = [
  'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve', 'diez',
  'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve', 'veinte',
];

String spokenNumber(int n) => n >= 0 && n < _numbers.length ? _numbers[n] : '$n';
