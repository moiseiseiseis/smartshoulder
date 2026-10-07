import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final storage = Storage(await SharedPreferences.getInstance());
  runApp(ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const SmartShoulderApp(),
  ));
}
