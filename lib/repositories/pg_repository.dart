// pg_repository.dart
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/pg_details.dart';

class PGRepository {
  final DatabaseHelper _db;

  PGRepository(this._db);

  Future<PGDetails?> getPGDetails() async {
    final maps = await _db.query('PG_Details');
    if (maps.isEmpty) return null;
    return PGDetails.fromMap(maps.first);
  }

  Future<int> savePGDetails(PGDetails details) async {
    final existing = await getPGDetails();
    if (existing != null) {
      return await _db.update('PG_Details', details.toMap(), 'pg_id = ?', [existing.pgId]);
    } else {
      return await _db.insert('PG_Details', details.toMap());
    }
  }
}