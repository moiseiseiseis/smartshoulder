import 'package:dio/dio.dart';

import 'models.dart';
import 'storage.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);

  /// 4xx distinto de 401/408/429: reintentar no sirve.
  bool get permanent => status != null && status! >= 400 && status! < 500 && status != 401 && status != 408 && status != 429;

  @override
  String toString() => message;
}

class Api {
  final Storage storage;
  Api(this.storage);

  Dio get _dio => Dio(BaseOptions(
        baseUrl: storage.apiUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        headers: {if (storage.token != null) 'Authorization': 'Bearer ${storage.token}'},
      ));

  Future<T> _call<T>(Future<Response<dynamic>> Function(Dio) f, T Function(dynamic) parse) async {
    try {
      final r = await f(_dio);
      return parse(r.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final msg = body is Map && body['message'] != null
          ? (body['message'] is List ? (body['message'] as List).join(' · ') : body['message'].toString())
          : status == null
              ? 'Sin conexión con el servidor.'
              : 'Error $status';
      throw ApiException(msg, status);
    }
  }

  /// Entrar con el código que da el fisio.
  Future<void> redeem(String code) async {
    final token = await _call((d) => d.post('/auth/redeem', data: {'code': code.trim().toUpperCase()}), (j) => j['token'] as String);
    await storage.setToken(token);
  }

  Future<MeData> me() => _call((d) => d.get('/me'), (j) => MeData.fromJson(j as Map<String, dynamic>));

  Future<HistoryData> history() => _call((d) => d.get('/me/sessions'), (j) => HistoryData.fromJson(j as Map<String, dynamic>));

  /// Devuelve el estado que calculó el backend (COMPLETE / INCOMPLETE / ABORTED).
  Future<String> uploadSession(Map<String, dynamic> body) =>
      _call((d) => d.post('/sessions', data: body), (j) => j['status'] as String);
}
