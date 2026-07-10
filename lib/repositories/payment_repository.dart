// payment_repository.dart
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/payment.dart';

class PaymentRepository {
  final DatabaseHelper _db;

  PaymentRepository(this._db);

  Future<List<Payment>> getPaymentsForGuest(int guestId) async {
    final maps = await _db.query('Payments', where: 'guest_id = ?', whereArgs: [guestId], orderBy: 'payment_date DESC');
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<int> addPayment(Payment payment) => _db.insert('Payments', payment.toMap());
  Future<int> updatePayment(Payment payment) => _db.update('Payments', payment.toMap(), 'payment_id = ?', [payment.paymentId]);
  Future<int> deletePayment(int id) => _db.delete('Payments', 'payment_id = ?', [id]);
}