// export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  static Future<bool> exportAllDataToCSV() async {
    try {
      final db = DatabaseHelper.instance;
      final tables = ['PG_Details', 'Rooms', 'Beds', 'Guests', 'Income', 'Expenses', 'Payments'];
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final table in tables) {
        final data = await db.query(table);
        if (data.isEmpty) continue;

        final csvContent = _convertToCSV(data);
        final file = File('${outputDir.path}/${table}_$timestamp.csv');
        await file.writeAsString(csvContent);
      }

      // Optionally share the files
      return true;
    } catch (e) {
      print('Export error: $e');
      return false;
    }
  }

  static String _convertToCSV(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';
    final headers = data.first.keys.join(',');
    final rows = data.map((row) => row.values.map((v) => v.toString()).join(',')).join('\n');
    return '$headers\n$rows';
  }

  static Future<bool> generateMonthlyReport(DateTime month, Map<String, dynamic> reportData) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, child: pw.Text('PG Management - Monthly Report', style: const pw.TextStyle(fontSize: 24))),
            pw.Header(level: 1, child: pw.Text(AppUtils.formatDate(DateTime(month.year, month.month, 1)))),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [pw.Text('Metric'), pw.Text('Value')]),
                pw.TableRow(children: [pw.Text('Total Income'), pw.Text(AppUtils.formatCurrency(reportData['totalIncome']))]),
                pw.TableRow(children: [pw.Text('Total Expense'), pw.Text(AppUtils.formatCurrency(reportData['totalExpense']))]),
                pw.TableRow(children: [pw.Text('Profit'), pw.Text(AppUtils.formatCurrency(reportData['profit']))]),
                pw.TableRow(children: [pw.Text('Occupancy Rate'), pw.Text('${reportData['occupancyRate'].toStringAsFixed(1)}%')]),
                pw.TableRow(children: [pw.Text('Pending Rent'), pw.Text(AppUtils.formatCurrency(reportData['pendingRent']))]),
                pw.TableRow(children: [pw.Text('Total Guests'), pw.Text(reportData['totalGuests'].toString())]),
              ],
            ),
          ],
        ),
      );

      final outputDir = await getApplicationDocumentsDirectory();
      final file = File('${outputDir.path}/Monthly_Report_${AppUtils.getBackupFileName().replaceAll('.db', '.pdf')}');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Monthly Report');
      return true;
    } catch (e) {
      print('PDF export error: $e');
      return false;
    }
  }
}