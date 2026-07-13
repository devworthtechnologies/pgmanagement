import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/bed.dart';

class BedRepository {
  final DatabaseHelper _db;

  BedRepository(this._db);

  Future<List<Bed>> getBedsForRoom(int roomId) async {
    final maps = await _db.query('Beds', where: 'room_id = ?', whereArgs: [roomId]);
    return maps.map((m) => Bed.fromMap(m)).toList();
  }

  Future<List<Bed>> getAvailableBedsForRoom(int roomId) async {
    final maps = await _db.query('Beds', where: 'room_id = ? AND status = ?', whereArgs: [roomId, 'Available']);
    return maps.map((m) => Bed.fromMap(m)).toList();
  }

  Future<int> addBed(Bed bed) => _db.insert('Beds', bed.toMap());
  Future<int> updateBed(Bed bed) => _db.update('Beds', bed.toMap(), 'bed_id = ?', [bed.bedId]);
  Future<int> deleteBed(int id) => _db.delete('Beds', 'bed_id = ?', [id]);
}