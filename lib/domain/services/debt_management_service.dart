import '../entities/debt.dart';
import '../entities/expense.dart';

/// Service untuk mengelola prioritas hutang dan proyeksi arus kas.
class DebtManagementService {
  
  /// Menganalisis Expense yang bertipe hutang dan menghasilkan entity Debt dengan skor prioritas.
  Debt analyzeDebt(Expense expense) {
    final score = _calculateScore(expense);
    final status = _determineStatus(score);
    
    // Prediksi jatuh tempo (default 30 hari dari tanggal transaksi jika tidak ada)
    final dueDate = expense.date.add(const Duration(days: 30));
    
    return Debt(
      priorityScore: score,
      priorityStatus: status,
      dueDate: dueDate,
    )..expense.target = expense;
  }

  /// Menghitung skor prioritas (0-100).
  /// Bobot: 40% Keterlambatan, 30% Penggunaan Limit, 30% Faktor Strategis.
  double _calculateScore(Expense expense) {
    if (expense.debtStatus == null || expense.debtStatus == 'LUNAS') return 0;
    
    double score = 0;
    final now = DateTime.now();
    
    // 1. Komponen Keterlambatan (Max 40)
    final daysPassed = now.difference(expense.date).inDays;
    const termDays = 30; 
    if (daysPassed > termDays) {
      final overdueDays = daysPassed - termDays;
      score += (overdueDays >= 30) ? 40 : (overdueDays / 30) * 40;
    }
    
    // 2. Komponen Limit Kredit (Max 30)
    final supplier = expense.supplier.target;
    if (supplier != null && supplier.creditLimit > 0) {
      final balance = expense.debtBalance ?? 0;
      final usage = balance / supplier.creditLimit;
      score += (usage >= 1.0) ? 30 : usage * 30;
    } else {
      // Jika tidak ada limit, beri skor moderate jika balance besar
      if ((expense.debtBalance ?? 0) > 1000000) score += 15;
    }
    
    // 3. Komponen Strategis (Max 30)
    if (supplier?.isStrategic ?? false) {
      score += 30;
    }
    
    return score > 100 ? 100 : score;
  }

  String _determineStatus(double score) {
    if (score >= 70) return 'PAY_NOW';
    if (score >= 40) return 'THIS_WEEK';
    if (score >= 20) return 'NEXT_WEEK';
    return 'DEFER';
  }
}
