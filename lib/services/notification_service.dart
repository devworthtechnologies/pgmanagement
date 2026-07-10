// notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    // Windows settings
    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
      appName: 'PG Manager',
      appUserModelId: 'com.example.pg_manager',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );

    // Combined settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );

    await _notifications.initialize(initializationSettings);
  }

  static Future<void> showRentDueNotification(
    String guestName,
    double amount,
    DateTime dueDate,
  ) async {
    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'rent_channel',
      'Rent Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    // Windows notification details
    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      windows: windowsDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Rent Due Tomorrow',
      '$guestName - Rent of ₹${amount.toStringAsFixed(2)} is due tomorrow',
      details,
    );
  }

  static Future<void> scheduleDailyBackupReminder() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'backup_channel',
      'Backup Reminders',
      importance: Importance.low,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      windows: windowsDetails,
    );

    await _notifications.periodicallyShow(
      999,
      'Backup Reminder',
      'Don\'t forget to backup your PG data to Google Drive',
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
