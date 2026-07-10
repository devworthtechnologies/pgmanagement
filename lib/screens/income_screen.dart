// income_screen.dart
import 'package:flutter/material.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/models/income.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/widgets/empty_state.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  List<Income> _incomes = [];
  bool _loading = true;
  DateTime? _filterMonth;

  @override
  void initState() {
    super.initState();
    _loadIncomes();
  }

  Future<void> _loadIncomes() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    String? where;
    List? whereArgs;
    if (_filterMonth != null) {
      final start = DateTime(_filterMonth!.year, _filterMonth!.month, 1);
      final end = DateTime(_filterMonth!.year, _filterMonth!.month + 1, 0);
      where = 'date BETWEEN ? AND ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    }
    final maps = await db.query('Income', where: where, whereArgs: whereArgs, orderBy: 'date DESC');
    setState(() {
      _incomes = maps.map((m) => Income.fromMap(m)).toList();
      _loading = false;
    });
  }

  Future<void> _addEditIncome([Income? income]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _IncomeFormDialog(income: income),
    );
    if (result == true) _loadIncomes();
  }

  Future<void> _deleteIncome(Income income) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final db = DatabaseHelper.instance;
      await db.delete('Income', 'income_id = ?', [income.incomeId]);
      _loadIncomes();
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterMonth ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _filterMonth = picked);
      _loadIncomes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _selectMonth,
          ),
          if (_filterMonth != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _filterMonth = null);
                _loadIncomes();
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEditIncome(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _incomes.isEmpty
              ? EmptyState(
                  title: 'No Income Records',
                  message: 'Tap + to add income like rent, deposit, etc.',
                  icon: Icons.attach_money,
                  onAction: () => _addEditIncome(),
                  actionLabel: 'Add Income',
                )
              : ListView.builder(
                  itemCount: _incomes.length,
                  itemBuilder: (ctx, i) {
                    final inc = _incomes[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(inc.type[0])),
                        title: Text('${inc.type} - ${AppUtils.formatCurrency(inc.amount)}'),
                        subtitle: Text('${AppUtils.formatDate(inc.date)} ${inc.description ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _addEditIncome(inc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteIncome(inc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _IncomeFormDialog extends StatefulWidget {
  final Income? income;

  const _IncomeFormDialog({this.income});

  @override
  State<_IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<_IncomeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = AppConstants.incomeTypes.first;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.income != null) {
      _type = widget.income!.type;
      _amountController.text = widget.income!.amount.toString();
      _descriptionController.text = widget.income!.description ?? '';
      _date = widget.income!.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.income == null ? 'Add Income' : 'Edit Income'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: AppConstants.incomeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(AppUtils.formatDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final income = Income(
                incomeId: widget.income?.incomeId,
                type: _type,
                amount: double.parse(_amountController.text),
                guestId: null, // optional, could add guest picker later
                date: _date,
                description: _descriptionController.text,
              );
              final db = DatabaseHelper.instance;
              if (widget.income == null) {
                await db.insert('Income', income.toMap());
              } else {
                await db.update('Income', income.toMap(), 'income_id = ?', [widget.income!.incomeId]);
              }
              Navigator.pop(context, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}