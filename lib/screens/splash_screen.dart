// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/services/google_signin_service.dart';
import 'package:pg_management/services/backup_service.dart';
import 'package:pg_management/screens/login_screen.dart';
import 'package:pg_management/screens/setup_wizard_screen.dart';
import 'package:pg_management/screens/dashboard_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final isSignedIn = await GoogleSignInService().isSignedIn();
    final hasPGSetup = prefs.getBool(SharedPrefKeys.hasPGSetup) ?? false;

    if (!isSignedIn) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else if (!hasPGSetup) {
      // Check for backup
      final backupService = BackupService();
      final hasBackup = await backupService.checkBackupExists();

      if (hasBackup) {
        _showRestoreDialog();
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SetupWizardScreen()));
      }
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Backup Found'),
        content: const Text(
            'Previous backup found on Google Drive. Do you want to restore it?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SetupWizardScreen()));
            },
            child: const Text('Start Fresh'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final backupService = BackupService();
              final success = await backupService.restoreBackup();
              if (success && mounted) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(SharedPrefKeys.hasPGSetup, true);
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Restore failed. Starting fresh.')),
                );
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SetupWizardScreen()));
              }
            },
            child: const Text('Restore Backup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.house, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
