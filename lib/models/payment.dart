// payment.dart
class Payment {
  final int? paymentId;
  final int guestId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? notes;

  Payment({
    this.paymentId,
    required this.guestId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'guest_id': guestId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      paymentId: map['payment_id'],
      guestId: map['guest_id'],
      amount: map['amount'],
      paymentDate: DateTime.parse(map['payment_date']),
      paymentMethod: map['payment_method'],
      notes: map['notes'],
    );
  }
}
