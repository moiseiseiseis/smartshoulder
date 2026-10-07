import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Lo poco que la app guarda en el teléfono (contexto/01 §8: datos locales mínimos).
class Storage {
  final SharedPreferences _p;
  Storage(this._p);

  static const _token = 'token';
  static const _consent = 'consent_v1';
  static const _apiUrl = 'api_url';
  static const _simulator = 'simulated_device';
  static const _pending = 'pending_sessions';
  static const _voice = 'voice_enabled';

  String? get token => _p.getString(_token);
  Future<void> setToken(String? v) => v == null ? _p.remove(_token) : _p.setString(_token, v);

  bool get consented => _p.getBool(_consent) ?? false;
  Future<void> setConsented() => _p.setBool(_consent, true);

  String get apiUrl => _p.getString(_apiUrl) ?? defaultApiUrl();
  Future<void> setApiUrl(String v) => _p.setString(_apiUrl, v.trim().replaceAll(RegExp(r'/+$'), ''));

  bool get simulator => _p.getBool(_simulator) ?? false;
  Future<void> setSimulator(bool v) => _p.setBool(_simulator, v);

  bool get voice => _p.getBool(_voice) ?? true;
  Future<void> setVoice(bool v) => _p.setBool(_voice, v);

  /// Sesiones terminadas que aún no se suben (sin internet).
  List<Map<String, dynamic>> get pending =>
      (_p.getStringList(_pending) ?? []).map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  Future<void> setPending(List<Map<String, dynamic>> v) => _p.setStringList(_pending, v.map(jsonEncode).toList());

  Future<void> logout() async {
    await _p.remove(_token);
    await _p.remove(_consent);
  }
}
