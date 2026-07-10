// main.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pg_management/core/constants.dart';
import 'package:pg_management/core/themes.dart';
import 'package:pg_management/providers/providers.dart';
import 'package:pg_management/screens/splash_screen.dart';
import 'package:pg_management/services/notification_service.dart';
import 'package:pg_management/services/rent_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final rentService = RentService();

    try {
      await rentService.generateMonthlyRentIncomes();
    } catch (e) {
      debugPrint("Background task error: $e");
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();

    databaseFactory = databaseFactoryFfi;

    debugPrint("Desktop SQLite initialized");
  }

  // Initialize notifications
  await NotificationService.initialize();

  // Initialize Workmanager only on Android/iOS
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      "rent-generation",
      "rentGenerationTask",
      frequency: const Duration(days: 1),
    );
  }

  runApp(
    const ProviderScope(
      child: PGManagementApp(),
    ),
  );
}

class PGManagementApp extends ConsumerWidget {
  const PGManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
