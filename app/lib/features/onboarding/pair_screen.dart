import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/device/device_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Emparejamiento del reloj asignado. Pensado para hacerse en consulta, con el fisio al lado (contexto/07 §5.2).
class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(meProvider).valueOrNull;
    final snap = ref.watch(deviceSnapshotProvider).valueOrNull ?? const DeviceSnapshot();
    final name = me?.deviceName;
    final busy = snap.conn == ConnState.searching || snap.conn == ConnState.connecting;

    return Scaffold(
      appBar: AppBar(title: const Text('Tu reloj')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(snap.connected ? Icons.check_circle : Icons.watch_outlined, size: 96, color: snap.connected ? SsColors.verified : SsColors.primary),
              const SizedBox(height: 24),
              Text(
                snap.connected ? '¡Listo! Tu reloj está conectado' : 'Conecta tu reloj',
                textAlign: TextAlign.center,
                style: t.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                snap.connected
                    ? 'Póntelo en la muñeca del brazo ${me?.rightArm == false ? 'izquierdo' : 'derecho'}, con la flecha ▲ hacia los dedos.'
                    : 'Tu clínica te prestó el reloj $name. Acércalo al teléfono.',
                textAlign: TextAlign.center,
                style: t.bodyLarge,
              ),
              if (name != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: 'monospace')),
                ),
              if (snap.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(snap.error!, textAlign: TextAlign.center, style: const TextStyle(color: SsColors.danger, fontSize: 16)),
                ),
              const Spacer(),
              if (snap.connected) ...[
                OutlinedButton.icon(
                  onPressed: () => ref.read(deviceProvider).identify(),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hacer parpadear la luz'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => context.go('/'), child: const Text('Continuar')),
              ] else
                FilledButton(
                  onPressed: busy || name == null ? null : () => ref.read(deviceProvider).connect(name),
                  child: busy
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
                          const SizedBox(width: 12),
                          Text(snap.conn == ConnState.searching ? 'Buscando…' : 'Conectando…'),
                        ])
                      : const Text('Conectar reloj'),
                ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.go('/'), child: const Text('Hacerlo después')),
            ],
          ),
        ),
      ),
    );
  }
}
