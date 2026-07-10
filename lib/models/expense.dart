// expense.dart
class Expense {
  final int? expenseId;
  final String category;
  final double amount;
  final DateTime date;
  final String? description;
  final String? attachmentPath;

  Expense({
    this.expenseId,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'expense_id': expenseId,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'attachment_path': attachmentPath,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      expenseId: map['expense_id'],
      category: map['category'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      attachmentPath: map['attachment_path'],
    );
  }
}
