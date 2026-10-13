import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'voice.dart';

/// Lo que el paciente oye y siente durante la sesión (doc 09 §6):
/// voz para las instrucciones, sonido suave por repetición (o voz que cuenta, si lo eligió) y vibración ligera.
/// Los sonidos son propios (generados por síntesis), sin licencias de terceros.
class SessionFeedback {
  final Voice voice;
  final bool sounds;
  final bool voiceCounting;
  final Map<String, AudioPool> _pools = {};

  SessionFeedback({required this.voice, required this.sounds, required this.voiceCounting});

  Future<void> init() async {
    if (!sounds) return;
    for (final name in ['rep', 'set_done', 'session_done']) {
      try {
        _pools[name] = await AudioPool.create(source: AssetSource('sounds/$name.wav'), maxPlayers: 2);
      } catch (_) {
        // Sin audio disponible: la sesión sigue con voz y vibración.
      }
    }
  }

  Future<void> _play(String name) async {
    if (!sounds) return;
    try {
      await _pools[name]?.start(volume: 0.9);
    } catch (_) {}
  }

  void rep(int n) {
    HapticFeedback.lightImpact();
    if (voiceCounting) {
      voice.say(spokenNumber(n));
    } else {
      _play('rep');
    }
  }

  void setDone() => _play('set_done');

  void sessionDone() {
    HapticFeedback.mediumImpact();
    _play('session_done');
  }

  Future<void> dispose() async {
    for (final p in _pools.values) {
      await p.dispose();
    }
    await voice.stop();
  }
}
