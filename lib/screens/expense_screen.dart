// expense_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/models/expense.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/widgets/empty_state.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;
  String? _categoryFilter;
  DateTime? _filterMonth;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    String? where;
    List? whereArgs = [];
    if (_categoryFilter != null) {
      where = 'category = ?';
      whereArgs = [_categoryFilter];
    }
    if (_filterMonth != null) {
      final start = DateTime(_filterMonth!.year, _filterMonth!.month, 1);
      final end = DateTime(_filterMonth!.year, _filterMonth!.month + 1, 0);
      where = where == null ? 'date BETWEEN ? AND ?' : '$where AND date BETWEEN ? AND ?';
      whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    }
    final maps = await db.query('Expenses', where: where, whereArgs: whereArgs.isEmpty ? null : whereArgs, orderBy: 'date DESC');
    setState(() {
      _expenses = maps.map((m) => Expense.fromMap(m)).toList();
      _loading = false;
    });
  }

  Future<void> _addEditExpense([Expense? expense]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExpenseFormDialog(expense: expense),
    );
    if (result == true) _loadExpenses();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final db = DatabaseHelper.instance;
      await db.delete('Expenses', 'expense_id = ?', [expense.expenseId]);
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _categoryFilter = value == 'All' ? null : value);
              _loadExpenses();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'All', child: Text('All Categories')),
              ...AppConstants.expenseCategories.map((c) => PopupMenuItem(value: c, child: Text(c))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterMonth ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _filterMonth = picked);
                _loadExpenses();
              }
            },
          ),
          if (_filterMonth != null || _categoryFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _categoryFilter = null;
                  _filterMonth = null;
                });
                _loadExpenses();
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEditExpense(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? EmptyState(
                  title: 'No Expenses',
                  message: 'Tap + to add expense',
                  icon: Icons.money_off,
                  onAction: () => _addEditExpense(),
                  actionLabel: 'Add Expense',
                )
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) {
                    final exp = _expenses[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(exp.category[0])),
                        title: Text('${exp.category} - ${AppUtils.formatCurrency(exp.amount)}'),
                        subtitle: Text('${AppUtils.formatDate(exp.date)} ${exp.description ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _addEditExpense(exp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteExpense(exp),
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

class _ExpenseFormDialog extends StatefulWidget {
  final Expense? expense;

  const _ExpenseFormDialog({this.expense});

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _category = AppConstants.expenseCategories.first;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  File? _attachment;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _category = widget.expense!.category;
      _amountController.text = widget.expense!.amount.toString();
      _descriptionController.text = widget.expense!.description ?? '';
      _date = widget.expense!.date;
    }
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _attachment = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: 'Category'),
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
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickAttachment,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach Bill'),
                    ),
                  ),
                  if (_attachment != null)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () {},
                    ),
                ],
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
              final expense = Expense(
                expenseId: widget.expense?.expenseId,
                category: _category,
                amount: double.parse(_amountController.text),
                date: _date,
                description: _descriptionController.text,
                attachmentPath: _attachment?.path,
              );
              final db = DatabaseHelper.instance;
              if (widget.expense == null) {
                await db.insert('Expenses', expense.toMap());
              } else {
                await db.update('Expenses', expense.toMap(), 'expense_id = ?', [widget.expense!.expenseId]);
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