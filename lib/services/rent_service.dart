import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/guest.dart';
import 'package:pg_management/models/income.dart';
import 'package:pg_management/services/notification_service.dart';

class RentService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  get Utils => null;

  Future<void> generateMonthlyRentIncomes() async {
    final guests = await _db.getAllGuests();
    final currentMonth = DateTime.now();
    
    for (final guest in guests) {
      // Check if rent already generated for this month
      final existingRent = await _db.query(
        'Income',
        where: 'guest_id = ? AND type = ? AND date LIKE ?',
        whereArgs: [guest.guestId, 'Rent', '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}-%'],
      );
      
      if (existingRent.isEmpty) {
        // Generate rent income entry
        final rentDate = DateTime(currentMonth.year, currentMonth.month, guest.dueDate.clamp(1, 28));
        final rentIncome = Income(
          type: 'Rent',
          amount: guest.monthlyRent,
          guestId: guest.guestId,
          date: rentDate,
          description: 'Monthly rent for ${Utils.formatDate(DateTime(currentMonth.year, currentMonth.month, 1))}',
        );
        await _db.insert('Income', rentIncome.toMap());
        
        // Also create a pending payment record? Not required, income is recorded.
      }
    }
  }

  Future<List<Guest>> getRentDueSoon() async {
    final guests = await _db.getAllGuests();
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    
    return guests.where((guest) {
      final dueDateThisMonth = DateTime(today.year, today.month, guest.dueDate);
      return dueDateThisMonth.day == tomorrow.day;
    }).toList();
  }

  Future<void> checkAndSendRentDueNotifications() async {
    final dueSoon = await getRentDueSoon();
    for (final guest in dueSoon) {
      await NotificationService.showRentDueNotification(
        guest.fullName,
        guest.monthlyRent,
        DateTime.now().add(const Duration(days: 1)),
      );
    }
  }

  Future<double> getTotalRentCollectedForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final payments = await _db.query(
      'Payments',
      where: 'payment_date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    double total = 0;
    for (final p in payments) {
      total += p['amount'] as double;
    }
    return total;
  }
}