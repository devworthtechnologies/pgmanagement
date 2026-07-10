import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/services/export_service.dart';
import 'package:pg_management/widgets/loading_indicator.dart';
import 'package:pg_management/widgets/error_widget.dart'; // Add this line

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportData;
  final DatabaseHelper _db = DatabaseHelper.instance;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportData = _generateReport();
    });
  }

  Future<Map<String, dynamic>> _generateReport() async {
    final totalIncome = await _db.getTotalIncomeByMonth(_selectedMonth);
    final totalExpense = await _db.getTotalExpenseByMonth(_selectedMonth);
    final guests = await _db.getAllGuests();
    final rooms = await _db.getAllRooms();
    final pendingRent = await _db.getPendingRent();

    // Income breakdown by type
    final incomeByType = await _db.query('Income', where: 'date LIKE ?', whereArgs: ['${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}%']);
    final Map<String, double> incomeMap = {};
    for (var inc in incomeByType) {
      final type = inc['type'] as String;
      incomeMap[type] = (incomeMap[type] ?? 0) + (inc['amount'] as double);
    }

    // Expense breakdown by category
    final expenseByCat = await _db.query('Expenses', where: 'date LIKE ?', whereArgs: ['${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}%']);
    final Map<String, double> expenseMap = {};
    for (var exp in expenseByCat) {
      final cat = exp['category'] as String;
      expenseMap[cat] = (expenseMap[cat] ?? 0) + (exp['amount'] as double);
    }

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'profit': totalIncome - totalExpense,
      'occupancyRate': rooms.isEmpty ? 0 : (rooms.where((r) => r.status == 'Occupied').length / rooms.length) * 100,
      'pendingRent': pendingRent,
      'totalGuests': guests.length,
      'incomeBreakdown': incomeMap,
      'expenseBreakdown': expenseMap,
    };
  }

  Future<void> _exportReport() async {
    final data = await _reportData;
    final success = await ExportService.generateMonthlyReport(_selectedMonth, data);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report exported to PDF')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedMonth = picked);
                _loadReport();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _reportData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          if (snapshot.hasError) {
            return CustomErrorWidget(message: snapshot.error.toString(), onRetry: _loadReport);
          }
          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report for ${AppUtils.formatDate(DateTime(_selectedMonth.year, _selectedMonth.month, 1))}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  children: [
                    _infoCard('Total Income', AppUtils.formatCurrency(data['totalIncome']), Colors.green),
                    _infoCard('Total Expense', AppUtils.formatCurrency(data['totalExpense']), Colors.red),
                    _infoCard('Profit', AppUtils.formatCurrency(data['profit']), Colors.blue),
                    _infoCard('Occupancy Rate', '${data['occupancyRate'].toStringAsFixed(1)}%', Colors.orange),
                    _infoCard('Pending Rent', AppUtils.formatCurrency(data['pendingRent']), Colors.purple),
                    _infoCard('Total Guests', data['totalGuests'].toString(), Colors.teal),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Income Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: _buildPieChart(data['incomeBreakdown']),
                ),
                const SizedBox(height: 24),
                const Text('Expense Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: _buildPieChart(data['expenseBreakdown']),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data for this month'));
    }
    final entries = data.entries.toList();
    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          return PieChartSectionData(
            title: entry.key,
            value: entry.value,
            color: Colors.primaries[idx % Colors.primaries.length],
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }
}