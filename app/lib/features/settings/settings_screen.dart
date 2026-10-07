import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _url = TextEditingController(text: ref.read(storageProvider).apiUrl);
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final simulator = ref.watch(simulatorProvider);
    final loggedIn = storage.token != null;

    return Scaffold(
      appBar: AppBar(title: GestureDetector(onTap: () => setState(() => _taps++), child: const Text('Ajustes'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Guía por voz', style: TextStyle(fontSize: 18)),
          subtitle: const Text('Cuenta tus repeticiones en voz alta'),
          value: storage.voice,
          onChanged: (v) async {
            await storage.setVoice(v);
            ref.invalidate(voiceProvider);
            setState(() {});
          },
        ),
        const Divider(height: 32),
        Text('Servidor', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(border: OutlineInputBorder(), helperText: 'Lo configura la clínica. Ej. http://192.168.1.50:3001'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            await storage.setApiUrl(_url.text);
            ref.invalidate(apiProvider);
            ref.invalidate(meProvider);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servidor guardado')));
          },
          child: const Text('Guardar servidor'),
        ),
        // Modo demostración oculto: se muestra tras tocar 5 veces el título (plan B del Demo Day).
        if (simulator || _taps >= 5) ...[
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reloj simulado (demostración)', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Genera repeticiones sin el reloj real'),
            value: simulator,
            onChanged: (v) async {
              await ref.read(deviceProvider).disconnect();
              await storage.setSimulator(v);
              ref.read(simulatorProvider.notifier).state = v;
            },
          ),
        ],
        if (loggedIn) ...[
          const Divider(height: 32),
          OutlinedButton(
            onPressed: () async {
              await ref.read(deviceProvider).disconnect();
              await storage.logout();
              ref.read(authTickProvider.notifier).state++;
              if (context.mounted) context.go('/welcome');
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ]),
    );
  }
}
