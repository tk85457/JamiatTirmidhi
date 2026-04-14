import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'core/router.dart';
import 'features/settings/settings_provider.dart';
import 'data/isar/isar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for web or desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();

  // Pre-initialize Isar on non-web platforms (Isar uses FFI, not supported on web)
  if (!kIsWeb) {
    await IsarService.instance.db;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SunanIbnMajahApp(),
    ),
  );
}

class SunanIbnMajahApp extends ConsumerWidget {
  const SunanIbnMajahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final primaryColor = AppTheme.getPrimaryColor(settings.uiColor);

    return MaterialApp.router(
      title: 'Sunan Ibn Majah - Hadith',
      debugShowCheckedModeBanner: false,
      theme: settings.isDarkMode ? AppTheme.darkTheme(primaryColor) : AppTheme.lightTheme(primaryColor),
      routerConfig: goRouter,
    );
  }
}
