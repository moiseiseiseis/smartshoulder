// Contrato BLE de SmartShoulder: espejo de contracts/ble.md.
// Cualquier cambio aquí va en el mismo commit que firmware/smartshoulder/config.h.
import 'dart:typed_data';

String _uuid(String short) => '0ed8$short-8e11-4ac8-bea3-882874982696';

final uuidService = _uuid('0001');
final uuidControl = _uuid('0002');
final uuidEvents = _uuid('0003');
final uuidRawStream = _uuid('0004');
final uuidStatus = _uuid('0005');
const uuidBatteryService = '0000180f-0000-1000-8000-00805f9b34fb';
const uuidBatteryLevel = '00002a19-0000-1000-8000-00805f9b34fb';

const cmdStartSession = 0x01;
const cmdStopSession = 0x02;
const cmdSetArm = 0x03;
const cmdSetMode = 0x04;
const cmdSetExpected = 0x05;
const cmdSyncEvents = 0x06;
const cmdIdentify = 0x07;

const modeInference = 0;
const armRight = 0;
const armLeft = 1;

enum EventType { rep, exerciseChanged, sessionEnd, unknown }

/// Evento del dispositivo (característica EVENTS, 12 bytes little-endian).
class DeviceEvent {
  final EventType type;
  final int exerciseId;
  final int repIndex;
  final int confidence; // 0–255
  final int timestampMs;
  final int seq;

  const DeviceEvent({
    required this.type,
    required this.exerciseId,
    required this.repIndex,
    required this.confidence,
    required this.timestampMs,
    required this.seq,
  });

  factory DeviceEvent.parse(List<int> bytes) {
    if (bytes.length < 12) throw FormatException('EVENTS de ${bytes.length} bytes');
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    final t = d.getUint8(0);
    return DeviceEvent(
      type: switch (t) { 1 => EventType.rep, 2 => EventType.exerciseChanged, 3 => EventType.sessionEnd, _ => EventType.unknown },
      exerciseId: d.getUint8(1),
      repIndex: d.getUint16(2, Endian.little),
      confidence: d.getUint8(4),
      timestampMs: d.getUint32(6, Endian.little),
      seq: d.getUint16(10, Endian.little),
    );
  }

  int get typeCode => switch (type) { EventType.rep => 1, EventType.exerciseChanged => 2, EventType.sessionEnd => 3, EventType.unknown => 0 };

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'type': typeCode,
        'exerciseId': exerciseId,
        'repIndex': repIndex,
        'confidence': confidence,
        'deviceTimestampMs': timestampMs,
      };
}

/// Característica STATUS (6 bytes).
class DeviceStatusInfo {
  final int state, mode, arm, fwVersion, modelVersion;
  const DeviceStatusInfo(this.state, this.mode, this.arm, this.fwVersion, this.modelVersion);

  factory DeviceStatusInfo.parse(List<int> b) {
    if (b.length < 5) throw FormatException('STATUS de ${b.length} bytes');
    return DeviceStatusInfo(b[0], b[1], b[2], b[3], b[4]);
  }
}
