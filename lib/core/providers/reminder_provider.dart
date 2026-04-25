import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import 'pengaturan_provider.dart';
import 'transaction_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Provider untuk daftar transaksi yang memerlukan pengingat servis.
/// Memastikan hanya mengambil transaksi terbaru untuk setiap kendaraan yang sudah LUNAS.
final reminderTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactionsAsync = ref.watch(transactionListProvider);
  final settings = ref.watch(settingsProvider);
  final threshold = settings.reminderThresholdDays;

  return transactionsAsync.maybeWhen(
    data: (transactions) {
      // 1. Filter transaksi LUNAS yang memiliki rekomendasi waktu
      final validTransactions = transactions
          .where(
            (t) =>
                t.serviceStatus == ServiceStatus.lunas &&
                !t.isDeleted &&
                t.nextServiceDate != null,
          )
          .toList();

      // 2. Ambil transaksi TERBARU per kendaraan (berdasarkan kombinasi ID Pelanggan + ID Kendaraan)
      final latestTransactionsByVehicle = <String, Transaction>{};
      for (var t in validTransactions) {
        // Gunakan targetId untuk identitas unik di ObjectBox
        final vehicleId = t.vehicle.targetId;
        final customerId = t.pelanggan.targetId;
        final key = "${customerId}_$vehicleId";

        final currentLatest = latestTransactionsByVehicle[key];

        if (currentLatest == null || t.createdAt.isAfter(currentLatest.createdAt)) {
          latestTransactionsByVehicle[key] = t;
        }
      }

      // 3. Filter berdasarkan:
      // - Ambang batas hari (isDueSoon mencakup isOverdue)
      // - Anti-Spam (Sembunyikan jika baru dikirim < 7 hari)
      final filtered = latestTransactionsByVehicle.values
          .where((t) => t.isDueSoon(threshold) && !t.isRecentlyReminded)
          .toList();

      filtered.sort((a, b) => a.nextServiceDate!.compareTo(b.nextServiceDate!));
      return filtered;
    },
    orElse: () => [],
  );
});

/// Provider untuk jumlah total pengingat aktif (untuk ditampilkan di Bento Card).
final reminderCountProvider = Provider<int>((ref) {
  return ref.watch(reminderTransactionsProvider).length;
});

