// constants.dart
class AppConstants {
  static const String appName = 'PG Management';
  static const String backupFolder = 'PG_Backups';
  static const String backupFileName = 'PG_Backup';
  static const String dbFileName = 'pg_management.db';

  // Income Types
  static const List<String> incomeTypes = [
    'Rent',
    'Admission fee',
    'Deposit',
    'Laundry',
    'Food',
    'Parking',
    'Other'
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'Electricity',
    'Water',
    'WiFi',
    'Food',
    'Salary',
    'Repairs',
    'Maintenance',
    'Miscellaneous'
  ];

  // Payment Methods
  static const List<String> paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Card',
    'Cheque'
  ];

  // Gender Options
  static const List<String> genders = ['Male', 'Female', 'Other'];

  // ID Proof Types
  static const List<String> idProofTypes = [
    'Aadhar Card',
    'PAN Card',
    'Voter ID',
    'Driving License',
    'Passport'
  ];

  // Room Status
  static const String roomAvailable = 'Available';
  static const String roomOccupied = 'Occupied';
  static const String roomMaintenance = 'Maintenance';

  // Guest Status
  static const String guestActive = 'Active';
  static const String guestCheckedOut = 'Checked Out';
  static const String guestTransferred = 'Transferred';
}

class SharedPrefKeys {
  static const String isFirstLaunch = 'is_first_launch';
  static const String hasPGSetup = 'has_pg_setup';
  static const String userEmail = 'user_email';
  static const String notificationEnabled = 'notification_enabled';
  static const String backupReminder = 'backup_reminder';
}
