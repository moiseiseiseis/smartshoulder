import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'device/ble_device.dart';
import 'device/device_client.dart';
import 'device/simulated_device.dart';
import 'models.dart';
import 'storage.dart';
import 'sync.dart';
import 'voice.dart';

/// Se sobrescribe en main() con la instancia ya cargada.
final storageProvider = Provider<Storage>((_) => throw UnimplementedError());

final apiProvider = Provider<Api>((ref) => Api(ref.watch(storageProvider)));

final queueProvider = Provider<SessionQueue>((ref) => SessionQueue(ref.watch(storageProvider), ref.watch(apiProvider)));

/// Reloj simulado o real (Ajustes → modo demostración).
final simulatorProvider = StateProvider<bool>((ref) => ref.watch(storageProvider).simulator);

final deviceProvider = Provider<DeviceClient>((ref) {
  final d = ref.watch(simulatorProvider) ? SimulatedDevice() : BleDevice();
  ref.onDispose(d.dispose);
  return d;
});

final deviceSnapshotProvider = StreamProvider<DeviceSnapshot>((ref) async* {
  final d = ref.watch(deviceProvider);
  yield d.snapshot;
  yield* d.snapshots;
});

final voiceProvider = Provider<Voice>((ref) => Voice(enabled: ref.watch(storageProvider).voice));

final meProvider = FutureProvider<MeData>((ref) => ref.watch(apiProvider).me());

final historyProvider = FutureProvider<HistoryData>((ref) => ref.watch(apiProvider).history());

/// Cambia cuando el paciente entra o sale (el router lo escucha).
final authTickProvider = StateProvider<int>((_) => 0);
