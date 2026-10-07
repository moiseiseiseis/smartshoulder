import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

/// Entrada: el paciente escanea el QR que le muestra su fisio o escribe el código de 6 letras.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

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
    // smartshoulder://invite?code=XXXXXX&device=SS-54F5
    final uri = Uri.tryParse(result);
    final code = uri?.queryParameters['code'] ?? result;
    _code.text = code;
    await _redeem(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: SsColors.primarySoft, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.accessibility_new, color: SsColors.primary, size: 36),
              ),
            ),
            const SizedBox(height: 24),
            Text('Bienvenido a SmartShoulder', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text('Tus ejercicios de hombro en casa, con el seguimiento de tu fisioterapeuta.', style: t.bodyLarge),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: const Text('Escanear el código de mi fisio'),
            ),
            const SizedBox(height: 32),
            Text('O escribe el código de 6 letras', style: t.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 10),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onSubmitted: (v) => v.length == 6 ? _redeem(v) : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _code.text.trim().length == 6 ? _redeem(_code.text) : setState(() => _error = 'El código tiene 6 letras o números.'),
              child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : const Text('Entrar'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: SsColors.danger, fontSize: 16)),
            ],
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('Ajustes de conexión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
