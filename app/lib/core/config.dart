import 'package:flutter/foundation.dart';

/// URL de la API. Se puede fijar al compilar:  flutter run --dart-define=API_URL=http://192.168.1.50:3001
/// y cambiar después en Ajustes (útil cuando la laptop de la demo cambia de red).
const _fromDefine = String.fromEnvironment('API_URL');

String defaultApiUrl() {
  if (_fromDefine.isNotEmpty) return _fromDefine;
  if (kIsWeb) return 'http://localhost:3001';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3001'; // emulador → PC
  return 'http://localhost:3001';
}
