// guest_repository.dart
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/guest.dart';
import 'package:pg_management/core/constants.dart';

class GuestRepository {
  final DatabaseHelper _db;

  GuestRepository(this._db);

  Future<List<Guest>> getAllGuests() async {
    final maps = await _db.query('Guests',
        where: 'status = ?', whereArgs: [AppConstants.guestActive]);
    return maps.map((m) => Guest.fromMap(m)).toList();
  }

  Future<int> addGuest(Guest guest) async {
    return await _db.insert('Guests', guest.toMap());
  }

  Future<int> updateGuest(Guest guest) async {
    return await _db
        .update('Guests', guest.toMap(), 'guest_id = ?', [guest.guestId]);
  }

  Future<int> deleteGuest(int guestId) async {
    return await _db.delete('Guests', 'guest_id = ?', [guestId]);
  }

  Future<List<Guest>> searchGuests(String query) async {
    final maps = await _db.query(
      'Guests',
      where: 'full_name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return maps.map((m) => Guest.fromMap(m)).toList();
  }

  Future<void> checkoutGuest(int guestId) async {
    await _db.update('Guests', {'status': AppConstants.guestCheckedOut},
        'guest_id = ?', [guestId]);
  }
}
