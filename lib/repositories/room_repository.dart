// room_repository.dart
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/room.dart';
import 'package:pg_management/models/bed.dart';

class RoomRepository {
  final DatabaseHelper _db;

  RoomRepository(this._db);

  Future<List<Room>> getAllRooms() async {
    final maps = await _db.query('Rooms', orderBy: 'room_number ASC');
    return maps.map((m) => Room.fromMap(m)).toList();
  }

  Future<Room?> getRoomById(int id) async {
    final maps = await _db.query('Rooms', where: 'room_id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Room.fromMap(maps.first);
  }

  Future<int> addRoom(Room room) => _db.insert('Rooms', room.toMap());
  Future<int> updateRoom(Room room) => _db.update('Rooms', room.toMap(), 'room_id = ?', [room.roomId]);
  Future<int> deleteRoom(int id) => _db.delete('Rooms', 'room_id = ?', [id]);

  Future<List<Bed>> getBedsForRoom(int roomId) async {
    final maps = await _db.query('Beds', where: 'room_id = ?', whereArgs: [roomId]);
    return maps.map((m) => Bed.fromMap(m)).toList();
  }

  Future<int> addBed(Bed bed) => _db.insert('Beds', bed.toMap());
  Future<int> updateBed(Bed bed) => _db.update('Beds', bed.toMap(), 'bed_id = ?', [bed.bedId]);
  Future<int> deleteBed(int id) => _db.delete('Beds', 'bed_id = ?', [id]);
}