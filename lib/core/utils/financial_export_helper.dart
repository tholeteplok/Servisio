import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/expense.dart';

class FinancialExportHelper {
  static Future<void> generateFinancialReport({
    required List<Transaction> transactions,
    required List<Sale> sales,
    required List<Expense> expenses,
    required String bengkelName,
  }) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'LAPORAN KEUANGAN SERVISIO',
      '',
      '',
      '',
      '',
      '',
    ]);
    rows.add(['Bengkel:', bengkelName]);
    rows.add(['Tanggal Cetak:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())]);
    rows.add([]);

    // Column Headers
    rows.add([
      'TANGGAL',
      'KATEGORI',
      'REF/ID',
      'KETERANGAN',
      'METODE',
      'MASUK (Rp)',
      'KELUAR (Rp)',
    ]);

    // Data Aggregation
    final List<_ReportEntry> entries = [];

    // 1. Transactions (Service)
    for (final tx in transactions) {
      if (tx.isDeleted) continue;
      entries.add(_ReportEntry(
        date: tx.updatedAt,
        category: 'SERVIS',
        ref: tx.trxNumber,
        description: '${tx.customerName} - ${tx.vehicleModel}',
        method: tx.paymentMethod ?? '-',
        income: tx.totalAmount.toDouble(),
        expense: 0,
      ));
    }

    // 2. Sales (Direct)
    for (final s in sales) {
      if (s.isDeleted) continue;
      entries.add(_ReportEntry(
        date: s.createdAt,
        category: 'PENJUALAN',
        ref: s.trxNumber,
        description: '${s.itemName} (x${s.quantity})',
        method: s.paymentMethod ?? '-',
        income: s.totalPrice.toDouble(),
        expense: 0,
      ));
    }

    // 3. Expenses
    for (final e in expenses) {
      if (e.isDeleted) continue;
      // Skip debt parents (they don't involve cash flow until paid)
      // Only include paid records or records without debt status
      if (e.debtStatus == 'HUTANG') continue; 

      entries.add(_ReportEntry(
        date: e.date,
        category: 'PENGELUARAN',
        ref: '-',
        description: e.description ?? e.category,
        method: 'TUNAI', // Default for expense
        income: 0,
        expense: e.amount.toDouble(),
      ));
    }

    // Sort by Date
    entries.sort((a, b) => b.date.compareTo(a.date));

    // Add entries to rows
    double totalIncome = 0;
    double totalExpense = 0;

    for (final entry in entries) {
      rows.add([
        DateFormat('dd/MM/yyyy').format(entry.date),
        entry.category,
        entry.ref,
        entry.description,
        entry.method,
        entry.income,
        entry.expense,
      ]);
      totalIncome += entry.income;
      totalExpense += entry.expense;
    }

    rows.add([]);
    rows.add(['TOTAL', '', '', '', '', totalIncome, totalExpense]);
    rows.add(['SALDO BERSIH', '', '', '', '', totalIncome - totalExpense, '']);

    // Generate CSV (Manual Formatting to avoid dependency class issues)
    final String csvData = rows.map((row) {
      return row.map((field) {
        final String fieldStr = field.toString().replaceAll('"', '""');
        return fieldStr.contains(',') || fieldStr.contains('"') || fieldStr.contains('\n') 
          ? '"$fieldStr"' 
          : fieldStr;
      }).join(',');
    }).join('\n');

    // Save File
    final directory = await getTemporaryDirectory();
    final fileName = 'Laporan_Keuangan_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final path = '${directory.path}/$fileName';
    final file = File(path);

    await file.writeAsString(csvData);

    // Share
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Laporan Keuangan Servisio',
    );
  }
}

class _ReportEntry {
  final DateTime date;
  final String category;
  final String ref;
  final String description;
  final String method;
  final double income;
  final double expense;

  _ReportEntry({
    required this.date,
    required this.category,
    required this.ref,
    required this.description,
    required this.method,
    required this.income,
    required this.expense,
  });
}
