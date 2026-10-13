import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/brand.dart';
import '../../ui/components.dart';

/// Bienvenida: 3 mensajes cortos y los dos caminos para entrar siempre visibles (no hace falta deslizar).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Slide {
  final IconData? icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = [
  _Slide(null, 'Bienvenido a Rumbo', 'Sus ejercicios de hombro en casa, con el acompañamiento de su fisioterapeuta.'),
  _Slide(LucideIcons.clipboardList, 'Su fisioterapeuta le marca el rumbo', 'Le indica qué ejercicios hacer y cuántas veces por semana.'),
  _Slide(LucideIcons.watch, 'El reloj cuenta por usted', 'Póngaselo en la muñeca, haga sus ejercicios y su fisioterapeuta verá su avance.'),
];

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _page = PageController();
  int _index = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _redeem(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).redeem(code);
      ref.read(authTickProvider.notifier).state++;
      if (mounted) context.go('/consent');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final result = await context.push<String>('/scan');
    if (result == null) return;
    // rumbo://invite?code=XXXXXX&device=RR-54F5
    final uri = Uri.tryParse(result);
    await _redeem(uri?.queryParameters['code'] ?? result);
  }

  Future<void> _typeCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RumboColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(RumboRadius.xl))),
      builder: (_) => const _CodeSheet(),
    );
    if (code != null) await _redeem(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(LucideIcons.settings, size: 18),
              label: const Text('Ajustes'),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _SlideView(_slides[i]),
            ),
          ),
          Semantics(
            label: 'Página ${_index + 1} de ${_slides.length}',
            child: ExcludeSemantics(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: RumboMotion.of(context, RumboMotion.normal),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == _index ? RumboColors.accent : RumboColors.line,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(children: [
              if (_error != null) ...[InlineNotice(kind: StatusKind.alert, text: _error!), const SizedBox(height: 12)],
              FilledButton.icon(
                onPressed: _busy ? null : _scan,
                icon: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Icon(LucideIcons.qrCode, size: 24),
                label: const Text('Escanear el código de mi fisio'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _typeCode,
                icon: const Icon(LucideIcons.keyboard, size: 22),
                label: const Text('Escribir el código'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide s;
  const _SlideView(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(children: [
        const SizedBox(height: 16),
        if (s.icon == null)
          const RumboLogo(fontSize: 52, vertical: true)
        else
          Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(color: RumboColors.primarySoft, shape: BoxShape.circle),
            child: Icon(s.icon, size: 60, color: RumboColors.primary),
          ),
        const SizedBox(height: 36),
        Text(s.title, textAlign: TextAlign.center, style: RumboText.screenTitle.copyWith(fontSize: 28)),
        const SizedBox(height: 12),
        Text(s.body, textAlign: TextAlign.center, style: RumboText.bodyRegular.copyWith(color: RumboColors.slate, fontSize: 19)),
      ]),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _code.text.trim().length == 6;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Escriba su código', style: RumboText.sectionTitle),
        const SizedBox(height: 4),
        const Text('Son 6 letras o números. Se lo da su fisioterapeuta.', style: RumboText.help),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) => v.trim().length == 6 ? Navigator.pop(context, v.trim()) : null,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 10, color: RumboColors.primary),
          decoration: const InputDecoration(counterText: '', hintText: 'ABC123', hintStyle: TextStyle(color: RumboColors.mist, letterSpacing: 10)),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: valid ? () => Navigator.pop(context, _code.text.trim()) : null, child: const Text('Entrar')),
      ]),
    );
  }
}
