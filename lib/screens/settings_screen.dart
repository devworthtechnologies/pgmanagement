import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/services/backup_service.dart';
import 'package:pg_management/services/export_service.dart';
import 'package:pg_management/services/google_signin_service.dart';
import 'package:pg_management/services/notification_service.dart';
import 'package:pg_management/providers/providers.dart';
import 'package:pg_management/screens/login_screen.dart';
import 'package:pg_management/screens/dashboard_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _backupReminder = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool(SharedPrefKeys.notificationEnabled) ?? true;
      _backupReminder = prefs.getBool(SharedPrefKeys.backupReminder) ?? true;
    });
  }

  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);
    final backupService = BackupService();
    final success = await backupService.backupDatabase();
    setState(() => _isBackingUp = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Backup successful' : 'Backup failed')),
    );
  }

  Future<void> _performRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text('This will replace all current data with the backup. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isRestoring = true);
      final backupService = BackupService();
      final success = await backupService.restoreBackup();
      setState(() => _isRestoring = false);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore successful. Restarting app...')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    final success = await ExportService.exportAllDataToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Data exported to device storage' : 'Export failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle light/dark theme'),
            value: themeMode == ThemeMode.dark,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive rent due and payment reminders'),
            value: _notificationsEnabled,
            onChanged: (val) async {
              setState(() => _notificationsEnabled = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(SharedPrefKeys.notificationEnabled, val);
            },
          ),
          SwitchListTile(
            title: const Text('Daily Backup Reminder'),
            subtitle: const Text('Get notified to backup your data'),
            value: _backupReminder,
            onChanged: (val) async {
              setState(() => _backupReminder = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(SharedPrefKeys.backupReminder, val);
              if (val) {
                await NotificationService.scheduleDailyBackupReminder();
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Now'),
            subtitle: const Text('Upload database to Google Drive'),
            trailing: _isBackingUp ? const CircularProgressIndicator() : null,
            onTap: _isBackingUp ? null : _performBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Backup'),
            subtitle: const Text('Download latest backup from Google Drive'),
            trailing: _isRestoring ? const CircularProgressIndicator() : null,
            onTap: _isRestoring ? null : _performRestore,
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export Data (CSV)'),
            subtitle: const Text('Export all tables to CSV files'),
            onTap: _exportData,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            trailing: const Icon(Icons.exit_to_app),
            onTap: () async {
              await GoogleSignInService().signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
    );
  }
}