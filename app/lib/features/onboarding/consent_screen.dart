import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Aviso de privacidad y consentimiento expreso (LFPDPPP: los datos de salud son datos sensibles).
/// Borrador para el prototipo: el texto legal final lo revisa el responsable del tratamiento de datos.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(meProvider);
    final clinic = me.valueOrNull?.clinicName ?? 'tu clínica';
    return Scaffold(
      appBar: AppBar(title: const Text('Tu privacidad')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Antes de empezar', style: t.headlineMedium),
                  const SizedBox(height: 16),
                  _point(Icons.fitness_center, 'Qué guardamos',
                      'Los ejercicios que haces, cuántas repeticiones registra el reloj y el dolor que tú nos indiques.'),
                  _point(Icons.visibility_outlined, 'Quién lo ve',
                      'Solo tu fisioterapeuta de $clinic, para saber cómo vas con tu rehabilitación en casa.'),
                  _point(Icons.health_and_safety_outlined, 'Qué no hacemos',
                      'La app no diagnostica ni cambia tu tratamiento. Eso lo decide tu fisioterapeuta.'),
                  _point(Icons.lock_outline, 'Tus derechos',
                      'Tus datos de salud son datos sensibles. Puedes pedir verlos, corregirlos o borrarlos con tu clínica.'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Leí el aviso y acepto que se registren mis datos de salud para mi tratamiento.', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: !_accepted
                      ? null
                      : () async {
                          await ref.read(storageProvider).setConsented();
                          ref.read(authTickProvider.notifier).state++;
                          final device = (await ref.read(meProvider.future)).deviceName;
                          if (context.mounted) context.go(device != null ? '/pair' : '/');
                        },
                  child: const Text('Continuar'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _point(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
            ]),
          ),
        ]),
      );
}
