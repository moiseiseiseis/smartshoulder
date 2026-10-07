import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/onboarding/pair_screen.dart';
import 'features/onboarding/scan_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/session/session_screen.dart';
import 'features/session/summary_screen.dart';
import 'features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(storageProvider);
  final refresh = ValueNotifier(0);
  ref.listen(authTickProvider, (_, v) => refresh.value = v);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final open = {'/welcome', '/scan', '/settings'}.contains(state.matchedLocation);
      if (storage.token == null) return open ? null : '/welcome';
      if (!storage.consented && state.matchedLocation != '/consent') return '/consent';
      if (state.matchedLocation == '/welcome') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),
      GoRoute(path: '/pair', builder: (_, __) => const PairScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/session',
        builder: (_, s) {
          final (me, verified) = s.extra! as (MeData, bool);
          return SessionScreen(me: me, verified: verified);
        },
      ),
      GoRoute(path: '/summary', builder: (_, s) => SummaryScreen(outcome: s.extra! as SessionOutcome)),
    ],
  );
});

class SmartShoulderApp extends ConsumerWidget {
  const SmartShoulderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SmartShoulder',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
