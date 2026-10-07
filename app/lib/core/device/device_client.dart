import '../contract.dart';

enum ConnState { disconnected, searching, connecting, connected }

class DeviceSnapshot {
  final ConnState conn;
  final String? name;
  final int? battery;
  final int? fwVersion;
  final int? modelVersion;
  final String? error;

  const DeviceSnapshot({this.conn = ConnState.disconnected, this.name, this.battery, this.fwVersion, this.modelVersion, this.error});

  bool get connected => conn == ConnState.connected;

  DeviceSnapshot copyWith({ConnState? conn, String? name, int? battery, int? fwVersion, int? modelVersion, String? error, bool clearError = false}) =>
      DeviceSnapshot(
        conn: conn ?? this.conn,
        name: name ?? this.name,
        battery: battery ?? this.battery,
        fwVersion: fwVersion ?? this.fwVersion,
        modelVersion: modelVersion ?? this.modelVersion,
        error: clearError ? null : (error ?? this.error),
      );
}

/// El reloj, visto desde la app. La app no procesa señal: solo manda comandos y recibe eventos (contexto/01 §5).
abstract class DeviceClient {
  Stream<DeviceSnapshot> get snapshots;
  DeviceSnapshot get snapshot;
  Stream<DeviceEvent> get events;

  /// Busca el reloj por su nombre (p. ej. "SS-54F5") y se conecta.
  Future<void> connect(String name);
  Future<void> disconnect();

  /// Inicia una sesión en modo inferencia con el brazo que se rehabilita.
  Future<void> startSession({required bool rightArm});

  /// Ejercicio de la serie actual (0 = ninguno, p. ej. durante el descanso).
  Future<void> setExpected(int exerciseId);
  Future<void> stopSession();
  Future<void> identify();

  /// Pide al reloj los eventos desde [fromSeq] (tras una reconexión).
  Future<void> syncEvents(int fromSeq);

  void dispose();
}
