// expense_repository.dart
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/expense.dart';

class ExpenseRepository {
  final DatabaseHelper _db;

  ExpenseRepository(this._db);

  Future<List<Expense>> getAllExpenses() async {
    final maps = await _db.query('Expenses', orderBy: 'date DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    final maps = await _db.query('Expenses', where: 'category = ?', whereArgs: [category], orderBy: 'date DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<List<Expense>> getExpensesByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final maps = await _db.query('Expenses', where: 'date BETWEEN ? AND ?', whereArgs: [start.toIso8601String(), end.toIso8601String()], orderBy: 'date DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    return await _db.insert('Expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    return await _db.update('Expenses', expense.toMap(), 'expense_id = ?', [expense.expenseId]);
  }

  Future<int> deleteExpense(int expenseId) async {
    return await _db.delete('Expenses', 'expense_id = ?', [expenseId]);
  }

  Future<double> getTotalExpenses() async {
    final maps = await _db.query('Expenses');
    double total = 0;
    for (var map in maps) {
      total += map['amount'] as double;
    }
    return total;
  }

  Future<double> getTotalExpensesByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final result = await _db.query('Expenses', where: 'date BETWEEN ? AND ?', whereArgs: [start.toIso8601String(), end.toIso8601String()]);
    double total = 0;
    for (var map in result) {
      total += map['amount'] as double;
    }
    return total;
  }
}