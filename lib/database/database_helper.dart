// database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/models/pg_details.dart';
import 'package:pg_management/models/room.dart';
import 'package:pg_management/models/guest.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbFileName);
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final docsPath = await getApplicationDocumentsDirectory();
    final path = join(docsPath.path, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // PG Details table
    await db.execute('''
      CREATE TABLE PG_Details(
        pg_id INTEGER PRIMARY KEY AUTOINCREMENT,
        pg_name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        address TEXT NOT NULL,
        total_rooms INTEGER NOT NULL,
        total_floors INTEGER NOT NULL,
        created_date TEXT NOT NULL
      )
    ''');

    // Rooms table
    await db.execute('''
      CREATE TABLE Rooms(
        room_id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_number TEXT NOT NULL,
        room_type TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        occupied_count INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // Beds table
    await db.execute('''
      CREATE TABLE Beds(
        bed_id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        bed_number TEXT NOT NULL,
        status TEXT NOT NULL,
        guest_id INTEGER,
        FOREIGN KEY (room_id) REFERENCES Rooms(room_id) ON DELETE CASCADE
      )
    ''');

    // Guests table
    await db.execute('''
      CREATE TABLE Guests(
        guest_id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        gender TEXT NOT NULL,
        id_proof_type TEXT NOT NULL,
        id_proof_number TEXT NOT NULL,
        emergency_contact TEXT NOT NULL,
        joining_date TEXT NOT NULL,
        room_id INTEGER,
        bed_id INTEGER,
        deposit_amount REAL NOT NULL,
        monthly_rent REAL NOT NULL,
        due_date INTEGER NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        photo_path TEXT,
        id_proof_path TEXT,
        FOREIGN KEY (room_id) REFERENCES Rooms(room_id),
        FOREIGN KEY (bed_id) REFERENCES Beds(bed_id)
      )
    ''');

    // Income table
    await db.execute('''
      CREATE TABLE Income(
        income_id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        guest_id INTEGER,
        date TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (guest_id) REFERENCES Guests(guest_id)
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE Expenses(
        expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        attachment_path TEXT
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE Payments(
        payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        guest_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (guest_id) REFERENCES Guests(guest_id)
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE Settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where,
      List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
      String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  // PG Details specific
  Future<PGDetails?> getPGDetails() async {
    final results = await query('PG_Details');
    if (results.isEmpty) return null;
    return PGDetails.fromMap(results.first);
  }

  // Room specific
  Future<List<Room>> getAllRooms() async {
    final results = await query('Rooms', orderBy: 'room_number ASC');
    return results.map((map) => Room.fromMap(map)).toList();
  }

  // Guest specific
  Future<List<Guest>> getAllGuests() async {
    final results = await query('Guests',
        where: 'status = ?',
        whereArgs: [AppConstants.guestActive],
        orderBy: 'full_name ASC');
    return results.map((map) => Guest.fromMap(map)).toList();
  }

  // Income reports
  Future<double> getTotalIncomeByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM Income WHERE date BETWEEN ? AND ?',
        [start.toIso8601String(), end.toIso8601String()]);
    return result.first['total'] as double? ?? 0.0;
  }

  // Expense reports
  Future<double> getTotalExpenseByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM Expenses WHERE date BETWEEN ? AND ?',
        [start.toIso8601String(), end.toIso8601String()]);
    return result.first['total'] as double? ?? 0.0;
  }

  // Pending rent calculation
  Future<double> getPendingRent() async {
    final db = await database;
    // Total rent incomes - total payments for active guests
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(i.amount), 0) - COALESCE(SUM(p.amount), 0) as pending
      FROM Guests g
      LEFT JOIN Income i ON g.guest_id = i.guest_id AND i.type = 'Rent'
      LEFT JOIN Payments p ON g.guest_id = p.guest_id
      WHERE g.status = 'Active'
    ''');
    return result.first['pending'] as double? ?? 0.0;
  }

  // Backup: copy database file
  Future<String> getDatabasePath() async {
    final docsPath = await getApplicationDocumentsDirectory();
    return join(docsPath.path, AppConstants.dbFileName);
  }
}
