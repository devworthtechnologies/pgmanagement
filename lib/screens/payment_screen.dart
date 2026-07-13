import 'package:flutter/material.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/models/guest.dart';
import 'package:pg_management/models/payment.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/widgets/empty_state.dart';

class PaymentScreen extends StatefulWidget {
  final Guest guest;

  const PaymentScreen({super.key, required this.guest});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<Payment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final maps = await db.query('Payments', where: 'guest_id = ?', whereArgs: [widget.guest.guestId], orderBy: 'payment_date DESC');
    setState(() {
      _payments = maps.map((m) => Payment.fromMap(m)).toList();
      _loading = false;
    });
  }

  Future<void> _addPayment() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String method = AppConstants.paymentMethods.first;
    DateTime paymentDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  items: AppConstants.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => method = v!,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(AppUtils.formatDate(paymentDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) paymentDate = picked;
                    (ctx as State).setState(() {});
                  },
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final payment = Payment(
                  guestId: widget.guest.guestId!,
                  amount: double.parse(amountController.text),
                  paymentDate: paymentDate,
                  paymentMethod: method,
                  notes: notesController.text,
                );
                final db = DatabaseHelper.instance;
                await db.insert('Payments', payment.toMap());
                Navigator.pop(ctx);
                _loadPayments();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments - ${widget.guest.fullName}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPayment,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? EmptyState(
                  title: 'No Payments',
                  message: 'Record payments received from this guest',
                  icon: Icons.payment,
                  onAction: _addPayment,
                  actionLabel: 'Add Payment',
                )
              : ListView.builder(
                  itemCount: _payments.length,
                  itemBuilder: (ctx, i) {
                    final p = _payments[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.receipt),
                        title: Text(AppUtils.formatCurrency(p.amount)),
                        subtitle: Text('${AppUtils.formatDate(p.paymentDate)} • ${p.paymentMethod}'),
                        trailing: Text(p.notes ?? ''),
                      ),
                    );
                  },
                ),
    );
  }
}