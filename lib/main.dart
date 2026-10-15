import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'core/router.dart';
import 'features/settings/settings_provider.dart';
import 'data/isar/isar_service.dart';
import 'core/ads/ad_free_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize sqflite for web or desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  AdFreeService.init(
    prefs,
  ); // 24h banner-free state must be known before first frame

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const JamiAtTirmidhiApp(),
    ),
  );

  // Initialize Isar purely in background after initial UI frame is drawn (prevents ANR)
  if (!kIsWeb) {
    // Wait until the home screen is up and idle: the first-run Isar sync copies
    // every hadith and would otherwise compete with the UI on low-end phones.
    Future<void>.delayed(const Duration(seconds: 8), () {
      IsarService.instance.init().catchError((e) {
        debugPrint('Non-blocking background IsarService init error: $e');
      });
    });
  }
}

class JamiAtTirmidhiApp extends ConsumerWidget {
  const JamiAtTirmidhiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final primaryColor = AppTheme.getPrimaryColor(settings.uiColor);

    return MaterialApp.router(
      title: 'Jami at-Tirmidhi Hadith',
      debugShowCheckedModeBanner: false,
      theme: settings.isDarkMode
          ? AppTheme.darkTheme(primaryColor)
          : AppTheme.lightTheme(primaryColor),
      routerConfig: goRouter,
    );
  }
}
