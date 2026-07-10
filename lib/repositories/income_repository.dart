// income_repository.dart
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/income.dart';

class IncomeRepository {
  final DatabaseHelper _db;

  IncomeRepository(this._db);

  Future<List<Income>> getAllIncomes() async {
    final maps = await _db.query('Income', orderBy: 'date DESC');
    return maps.map((m) => Income.fromMap(m)).toList();
  }

  Future<int> addIncome(Income income) => _db.insert('Income', income.toMap());
  Future<int> updateIncome(Income income) => _db.update('Income', income.toMap(), 'income_id = ?', [income.incomeId]);
  Future<int> deleteIncome(int id) => _db.delete('Income', 'income_id = ?', [id]);
}