import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../contract.dart';
import 'device_client.dart';

/// Reloj real por Bluetooth LE (flutter_reactive_ble, licencia BSD-3).
class BleDevice implements DeviceClient {
  final _ble = FlutterReactiveBle();
  final _snapshots = StreamController<DeviceSnapshot>.broadcast();
  final _events = StreamController<DeviceEvent>.broadcast();
  DeviceSnapshot _snap = const DeviceSnapshot();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  final List<StreamSubscription<List<int>>> _charSubs = [];
  String? _deviceId;
  int _lastSeq = -1;
  bool _sessionActive = false;

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

  QualifiedCharacteristic _char(String serviceUuid, String charUuid) => QualifiedCharacteristic(
        deviceId: _deviceId!,
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(charUuid),
      );

  Future<bool> _permissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    final r = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
    return r[Permission.bluetoothScan]!.isGranted && r[Permission.bluetoothConnect]!.isGranted ||
        r[Permission.locationWhenInUse]!.isGranted; // Android ≤ 11 usa ubicación
  }

  @override
  Future<void> connect(String name) async {
    await disconnect();
    _set(DeviceSnapshot(conn: ConnState.searching, name: name));
    if (!await _permissions()) {
      _set(_snap.copyWith(conn: ConnState.disconnected, error: 'Se necesita permiso de Bluetooth para conectar el reloj.'));
      return;
    }
    final found = Completer<DiscoveredDevice>();
    _scanSub = _ble.scanForDevices(withServices: [Uuid.parse(uuidService)], scanMode: ScanMode.lowLatency).listen(
      (d) {
        if (d.name == name && !found.isCompleted) found.complete(d);
      },
      onError: (Object e) {
        if (!found.isCompleted) found.completeError(e);
      },
    );
    try {
      final d = await found.future.timeout(const Duration(seconds: 15));
      await _scanSub?.cancel();
      _deviceId = d.id;
      _set(_snap.copyWith(conn: ConnState.connecting));
      _connSub = _ble.connectToDevice(id: d.id, connectionTimeout: const Duration(seconds: 15)).listen(
        _onConnection,
        onError: (Object e) => _set(_snap.copyWith(conn: ConnState.disconnected, error: 'No se pudo conectar: $e')),
      );
    } on TimeoutException {
      await _scanSub?.cancel();
      _set(_snap.copyWith(conn: ConnState.disconnected, error: 'No encontramos el reloj $name. ¿Está cerca y encendido?'));
    } catch (e) {
      await _scanSub?.cancel();
      _set(_snap.copyWith(conn: ConnState.disconnected, error: 'Error de Bluetooth: $e'));
    }
  }

  Future<void> _onConnection(ConnectionStateUpdate u) async {
    switch (u.connectionState) {
      case DeviceConnectionState.connected:
        try {
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) await _ble.requestMtu(deviceId: _deviceId!, mtu: 247);
          await _ble.discoverAllServices(_deviceId!);
          _subscribe();
          final status = DeviceStatusInfo.parse(await _ble.readCharacteristic(_char(uuidService, uuidStatus)));
          final battery = await _ble.readCharacteristic(_char(uuidBatteryService, uuidBatteryLevel));
          _set(_snap.copyWith(
            conn: ConnState.connected,
            fwVersion: status.fwVersion,
            modelVersion: status.modelVersion,
            battery: battery.isEmpty ? null : battery.first,
            clearError: true,
          ));
          // Reconexión a mitad de sesión: el reloj siguió contando; pedimos lo que no llegó (contexto/01 §5).
          if (_sessionActive) await syncEvents(_lastSeq + 1);
        } catch (e) {
          _set(_snap.copyWith(conn: ConnState.disconnected, error: 'El reloj no respondió: $e'));
        }
      case DeviceConnectionState.disconnected:
        for (final s in _charSubs) {
          await s.cancel();
        }
        _charSubs.clear();
        _set(_snap.copyWith(conn: ConnState.disconnected));
      case DeviceConnectionState.connecting:
        _set(_snap.copyWith(conn: ConnState.connecting));
      case DeviceConnectionState.disconnecting:
        break;
    }
  }

  void _subscribe() {
    _charSubs.add(_ble.subscribeToCharacteristic(_char(uuidService, uuidEvents)).listen((bytes) {
      try {
        final ev = DeviceEvent.parse(bytes);
        if (ev.seq <= _lastSeq && _lastSeq - ev.seq < 30000) return; // duplicado tras SYNC
        _lastSeq = ev.seq;
        _events.add(ev);
      } on FormatException {
        // paquete incompleto: se ignora
      }
    }));
    _charSubs.add(_ble.subscribeToCharacteristic(_char(uuidBatteryService, uuidBatteryLevel)).listen((b) {
      if (b.isNotEmpty) _set(_snap.copyWith(battery: b.first));
    }));
  }

  Future<void> _write(List<int> payload) async {
    if (_deviceId == null || !_snap.connected) return;
    await _ble.writeCharacteristicWithResponse(_char(uuidService, uuidControl), value: payload);
  }

  @override
  Future<void> disconnect() async {
    await _scanSub?.cancel();
    for (final s in _charSubs) {
      await s.cancel();
    }
    _charSubs.clear();
    await _connSub?.cancel(); // en reactive_ble, cancelar la suscripción desconecta
    _connSub = null;
    _deviceId = null;
    _set(const DeviceSnapshot());
  }

  @override
  Future<void> startSession({required bool rightArm}) async {
    _lastSeq = -1;
    _sessionActive = true;
    await _write([cmdSetMode, modeInference]);
    await _write([cmdSetArm, rightArm ? armRight : armLeft]);
    await _write([cmdStartSession]);
  }

  @override
  Future<void> setExpected(int exerciseId) => _write([cmdSetExpected, exerciseId]);

  @override
  Future<void> stopSession() async {
    _sessionActive = false;
    await _write([cmdStopSession]);
  }

  @override
  Future<void> identify() => _write([cmdIdentify]);

  @override
  Future<void> syncEvents(int fromSeq) => _write([cmdSyncEvents, fromSeq & 0xff, (fromSeq >> 8) & 0xff]);

  @override
  void dispose() {
    disconnect();
    _snapshots.close();
    _events.close();
  }
}
