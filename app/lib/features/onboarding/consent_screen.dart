import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

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
    final me = ref.watch(meProvider);
    final clinic = me.valueOrNull?.clinicName ?? 'su clínica';
    return Scaffold(
      appBar: AppBar(title: const Text('Su privacidad')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
              const Text('Antes de empezar', style: RumboText.screenTitle),
              const SizedBox(height: 20),
              const _Point(LucideIcons.activity, 'Qué guardamos', 'Los ejercicios que hace, cuántas repeticiones registra el reloj y el dolor que usted nos indique.'),
              _Point(LucideIcons.eye, 'Quién lo ve', 'Solo su fisioterapeuta de $clinic, para saber cómo va su rehabilitación en casa.'),
              const _Point(LucideIcons.shieldCheck, 'Qué no hacemos', 'La app no diagnostica ni cambia su tratamiento. Eso lo decide su fisioterapeuta.'),
              const _Point(LucideIcons.lock, 'Sus derechos', 'Sus datos de salud son datos sensibles. Puede pedir verlos, corregirlos o borrarlos con su clínica.'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              Material(
                color: _accepted ? RumboColors.primarySoft : RumboColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RumboRadius.md),
                  side: BorderSide(color: _accepted ? RumboColors.primary : RumboColors.line, width: 2),
                ),
                child: CheckboxListTile(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  title: const Text('Leí el aviso y acepto que se registren mis datos de salud para mi tratamiento.', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: RumboColors.ink)),
                ),
              ),
              const SizedBox(height: 12),
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
        ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Point(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: RumboColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: RumboColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: RumboText.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Text(body, style: RumboText.bodyRegular),
            ]),
          ),
        ]),
      );
}
