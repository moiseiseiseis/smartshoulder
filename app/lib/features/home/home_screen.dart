import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/device/device_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Inicio: la sesión de hoy y un solo botón grande (contexto/01 §4.2).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Al abrir: subir lo que haya quedado pendiente y reconectar el reloj si lo tiene.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final left = await ref.read(queueProvider).flush();
      if (left == 0) ref.invalidate(historyProvider);
      try {
        final me = await ref.read(meProvider.future);
        final device = ref.read(deviceProvider);
        if (me.deviceName != null && device.snapshot.conn == ConnState.disconnected) device.connect(me.deviceName!);
      } catch (_) {
        // Sin conexión: la pantalla ya muestra el error y el botón de reintentar.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartShoulder', style: TextStyle(fontWeight: FontWeight.w700, color: SsColors.primary)),
        actions: [
          IconButton(tooltip: 'Mi historial', iconSize: 28, onPressed: () => context.push('/history'), icon: const Icon(Icons.calendar_month_outlined)),
          IconButton(tooltip: 'Ajustes', iconSize: 28, onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(meProvider)),
        data: (m) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(meProvider);
            ref.invalidate(historyProvider);
            await ref.read(meProvider.future);
          },
          child: _HomeBody(me: m),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final MeData me;
  const _HomeBody({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final rx = me.prescription;
    final history = ref.watch(historyProvider).valueOrNull;
    final snap = ref.watch(deviceSnapshotProvider).valueOrNull ?? const DeviceSnapshot();
    final hasDevice = me.deviceName != null;
    final verified = hasDevice && snap.connected;
    final pending = ref.watch(queueProvider).pendingCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text('Hola, ${me.firstName}', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('${me.clinicName} · ${me.physioName}', style: t.bodySmall),
        const SizedBox(height: 20),
        if (history != null && history.streak > 0) ...[
          _Streak(days: history.streak, doneToday: history.doneToday),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tu sesión de hoy', style: t.titleLarge),
              const SizedBox(height: 4),
              if (rx != null) Text('${rx.exercises.length} ejercicios · ${_duration(rx)}', style: t.bodySmall),
              const SizedBox(height: 12),
              if (rx == null)
                Text('Tu fisioterapeuta aún no te asigna ejercicios.', style: t.bodyLarge)
              else
                for (final e in rx.exercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 8, color: SsColors.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.name, style: t.bodyLarge)),
                      Text('${e.sets} × ${e.reps}', style: t.titleMedium),
                    ]),
                  ),
              if (rx?.notes != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: SsColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: Text('Nota de tu fisio: ${rx!.notes}', style: t.bodyMedium),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _DeviceTile(me: me, snap: snap),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
          onPressed: rx == null ? null : () => context.push('/session', extra: (me, verified)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.play_arrow_rounded, size: 34),
            const SizedBox(width: 8),
            Text(history?.doneToday == true ? 'Hacer otra sesión' : 'Comenzar sesión', style: const TextStyle(fontSize: 22)),
          ]),
        ),
        if (hasDevice && !snap.connected) ...[
          const SizedBox(height: 8),
          Text('Si empiezas sin el reloj, marcarás tus series a mano.', textAlign: TextAlign.center, style: t.bodySmall),
        ],
        if (pending > 0) ...[
          const SizedBox(height: 16),
          Text('$pending sesión(es) guardada(s) en el teléfono, pendiente(s) de enviar.', textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ],
    );
  }
}

/// Duración aproximada: ~4 s por repetición más los descansos entre series y ejercicios.
String _duration(Prescription rx) {
  final sec = rx.totalReps * 4 + rx.exercises.fold(0, (a, e) => a + e.restSec * e.sets);
  final min = (sec / 60).round();
  return min <= 1 ? 'un par de minutos' : 'unos $min minutos';
}

class _Streak extends StatelessWidget {
  final int days;
  final bool doneToday;
  const _Streak({required this.days, required this.doneToday});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SsColors.verifiedSoft, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          const Icon(Icons.local_fire_department, color: SsColors.verified, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              doneToday ? '¡Hoy ya cumpliste! Llevas $days ${days == 1 ? 'día' : 'días'} seguidos.' : 'Llevas $days ${days == 1 ? 'día' : 'días'} seguidos. ¡No rompas la racha!',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: SsColors.verified),
            ),
          ),
        ]),
      );
}

class _DeviceTile extends ConsumerWidget {
  final MeData me;
  final DeviceSnapshot snap;
  const _DeviceTile({required this.me, required this.snap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = me.deviceName;
    if (name == null) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.back_hand_outlined, color: SsColors.reported, size: 32),
        title: Text('Sin reloj', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: Text('Marcarás tus series a mano al terminar cada una.', style: TextStyle(fontSize: 15)),
      );
    }
    final busy = snap.conn == ConnState.searching || snap.conn == ConnState.connecting;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(Icons.watch_outlined, size: 32, color: snap.connected ? SsColors.verified : SsColors.muted),
        title: Text(
          snap.connected ? 'Reloj conectado' : (busy ? 'Buscando tu reloj…' : 'Reloj desconectado'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          snap.connected ? '$name${snap.battery != null ? ' · batería ${snap.battery}%' : ''}' : (snap.error ?? '$name · acércalo al teléfono'),
          style: const TextStyle(fontSize: 15),
        ),
        trailing: snap.connected
            ? (snap.battery != null && snap.battery! < 20 ? const Icon(Icons.battery_alert, color: SsColors.danger) : null)
            : busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                : TextButton(onPressed: () => ref.read(deviceProvider).connect(name), child: const Text('Conectar')),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 56, color: SsColors.muted),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ]),
        ),
      );
}
