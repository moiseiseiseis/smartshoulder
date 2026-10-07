import 'api.dart';
import 'storage.dart';

/// Cola de sesiones por subir. La sesión se guarda en el teléfono antes de intentar enviarla,
/// y el `clientSessionId` hace que reintentar nunca la duplique en el servidor.
class SessionQueue {
  final Storage storage;
  final Api api;
  SessionQueue(this.storage, this.api);

  int get pendingCount => storage.pending.length;

  Future<void> enqueue(Map<String, dynamic> session) async {
    final list = storage.pending..add(session);
    await storage.setPending(list);
  }

  /// Intenta subir todo lo pendiente. Devuelve cuántas quedan.
  Future<int> flush() async {
    final remaining = <Map<String, dynamic>>[];
    for (final s in storage.pending) {
      try {
        await api.uploadSession(s);
      } on ApiException catch (e) {
        // Un error permanente (datos inválidos) no se arregla reintentando: se descarta para no bloquear la cola.
        if (!e.permanent) remaining.add(s);
      }
    }
    await storage.setPending(remaining);
    return remaining.length;
  }
}
