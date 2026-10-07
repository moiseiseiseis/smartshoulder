import 'dart:async';
import 'dart:math';

import '../contract.dart';
import 'device_client.dart';

/// Reloj simulado: genera repeticiones del ejercicio esperado con un ritmo realista (~3 s por repetición).
/// Sirve para desarrollar sin hardware y como plan B en el escenario si falla el Bluetooth.
class SimulatedDevice implements DeviceClient {
  final _snapshots = StreamController<DeviceSnapshot>.broadcast();
  final _events = StreamController<DeviceEvent>.broadcast();
  final _rng = Random(7);
  DeviceSnapshot _snap = const DeviceSnapshot();
  Timer? _timer;
  bool _session = false;
  int _expected = 0;
  int _rep = 0;
  int _seq = 0;
  final _clock = Stopwatch();

  /// Segundos por repetición (configurable para pruebas).
  final double secondsPerRep;
  SimulatedDevice({this.secondsPerRep = 3.0});

  @override
  Stream<DeviceSnapshot> get snapshots => _snapshots.stream;
  @override
  DeviceSnapshot get snapshot => _snap;
  @override
  Stream<DeviceEvent> get events => _events.stream;

  void _set(DeviceSnapshot s) {
    _snap = s;
    _snapshots.add(s);
  }

  @override
  Future<void> connect(String name) async {
    _set(_snap.copyWith(conn: ConnState.searching, name: name, clearError: true));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _set(_snap.copyWith(conn: ConnState.connecting));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _set(_snap.copyWith(conn: ConnState.connected, battery: 82, fwVersion: 1, modelVersion: 1));
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _set(const DeviceSnapshot());
  }

  @override
  Future<void> startSession({required bool rightArm}) async {
    _session = true;
    _seq = 0;
    _clock
      ..reset()
      ..start();
  }

  @override
  Future<void> setExpected(int exerciseId) async {
    _expected = exerciseId;
    _rep = 0;
    _timer?.cancel();
    if (!_session || exerciseId == 0) return;
    _emit(EventType.exerciseChanged);
    _schedule();
  }

  void _schedule() {
    final jitter = 0.8 + _rng.nextDouble() * 0.4;
    _timer = Timer(Duration(milliseconds: (secondsPerRep * 1000 * jitter).round()), () {
      if (!_session || _expected == 0) return;
      _rep++;
      _emit(EventType.rep);
      _schedule();
    });
  }

  void _emit(EventType type) {
    _events.add(DeviceEvent(
      type: type,
      exerciseId: _expected,
      repIndex: _rep,
      confidence: 215 + _rng.nextInt(40),
      timestampMs: _clock.elapsedMilliseconds,
      seq: _seq++,
    ));
  }

  @override
  Future<void> stopSession() async {
    _timer?.cancel();
    _session = false;
    _expected = 0;
  }

  @override
  Future<void> identify() async {}

  @override
  Future<void> syncEvents(int fromSeq) async {}

  @override
  void dispose() {
    _timer?.cancel();
    _snapshots.close();
    _events.close();
  }
}
