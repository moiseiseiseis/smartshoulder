import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/brand.dart';
import '../../ui/components.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _url = TextEditingController(text: ref.read(storageProvider).apiUrl);
  int _taps = 0;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Widget _switch({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged, IconData? icon}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: icon == null ? null : Icon(icon, color: RumboColors.primary),
        title: Text(title, style: RumboText.body.copyWith(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: RumboText.help),
        value: value,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final simulator = ref.watch(simulatorProvider);
    final loggedIn = storage.token != null;

    return Scaffold(
      // Modo demostración oculto: se muestra tras tocar 5 veces el título (plan B del Demo Day).
      appBar: AppBar(title: GestureDetector(onTap: () => setState(() => _taps++), child: const Text('Ajustes'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        const Text('Durante la sesión', style: RumboText.sectionTitle),
        const SizedBox(height: 4),
        RumboCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _switch(
              icon: LucideIcons.volume2,
              title: 'Voz con instrucciones',
              subtitle: 'Le dice qué ejercicio sigue y cuándo descansar',
              value: storage.voice,
              onChanged: (v) async {
                await storage.setVoice(v);
                ref.invalidate(voiceProvider);
                setState(() {});
              },
            ),
            const Divider(),
            _switch(
              icon: LucideIcons.bell,
              title: 'Sonido en cada repetición',
              subtitle: 'Un sonido suave cuando el reloj cuenta una',
              value: storage.sounds,
              onChanged: (v) async {
                await storage.setSounds(v);
                setState(() {});
              },
            ),
            const Divider(),
            _switch(
              icon: LucideIcons.messageCircle,
              title: 'Que la voz cuente',
              subtitle: '"Uno, dos, tres…" en lugar del sonido',
              value: storage.voiceCounting,
              onChanged: (v) async {
                await storage.setVoiceCounting(v);
                setState(() {});
              },
            ),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Conexión', style: RumboText.sectionTitle),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          style: RumboText.body,
          decoration: const InputDecoration(labelText: 'Servidor', helperText: 'Lo configura la clínica. Ej. http://192.168.1.50:3001'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () async {
            await storage.setApiUrl(_url.text);
            ref.invalidate(apiProvider);
            ref.invalidate(meProvider);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servidor guardado')));
          },
          child: const Text('Guardar servidor'),
        ),
        if (simulator || _taps >= 5) ...[
          const SizedBox(height: 24),
          RumboCard(
            color: RumboColors.warningSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _switch(
              icon: LucideIcons.watch,
              title: 'Reloj simulado (demostración)',
              subtitle: 'Genera repeticiones sin el reloj real',
              value: simulator,
              onChanged: (v) async {
                await ref.read(deviceProvider).disconnect();
                await storage.setSimulator(v);
                ref.read(simulatorProvider.notifier).state = v;
              },
            ),
          ),
        ],
        if (loggedIn) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              await ref.read(deviceProvider).disconnect();
              await storage.logout();
              ref.read(authTickProvider.notifier).state++;
              if (context.mounted) context.go('/welcome');
            },
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Cerrar sesión'),
          ),
        ],
        const SizedBox(height: 32),
        const Center(child: Opacity(opacity: 0.8, child: RumboLogo(fontSize: 22))),
      ]),
    );
  }
}
