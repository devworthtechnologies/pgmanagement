// income.dart
class Income {
  final int? incomeId;
  final String type;
  final double amount;
  final int? guestId;
  final DateTime date;
  final String? description;

  Income({
    this.incomeId,
    required this.type,
    required this.amount,
    this.guestId,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'income_id': incomeId,
      'type': type,
      'amount': amount,
      'guest_id': guestId,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      incomeId: map['income_id'],
      type: map['type'],
      amount: map['amount'],
      guestId: map['guest_id'],
      date: DateTime.parse(map['date']),
      description: map['description'],
    );
  }
}
