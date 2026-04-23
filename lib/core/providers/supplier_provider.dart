import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/debt_payment.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/repositories/debt_payment_repository.dart';
import 'objectbox_provider.dart';
import 'auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repositories
// ─────────────────────────────────────────────────────────────────────────────

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final db = ref.watch(dbProvider);
  return SupplierRepository(db.supplierBox);
});

final debtPaymentRepositoryProvider = Provider<DebtPaymentRepository>((ref) {
  final db = ref.watch(dbProvider);
  return DebtPaymentRepository(db.debtPaymentBox);
});

// ─────────────────────────────────────────────────────────────────────────────
// Notifiers
// ─────────────────────────────────────────────────────────────────────────────

class SupplierListNotifier extends StateNotifier<List<Supplier>> {
  final Ref ref;
  SupplierListNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    final repository = ref.read(supplierRepositoryProvider);
    final bengkelId = ref.read(bengkelIdProvider);
    if (bengkelId != null) {
      state = repository.getAll(bengkelId);
    }
  }

  void refresh() {
    _init();
  }

  Future<int> addSupplier(Supplier supplier) async {
    final repository = ref.read(supplierRepositoryProvider);
    final id = repository.save(supplier);
    refresh();
    return id;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final supplierListProvider = StateNotifierProvider<SupplierListNotifier, List<Supplier>>((ref) {
  return SupplierListNotifier(ref);
});

final debtPaymentListProvider = Provider<List<DebtPayment>>((ref) {
  final repository = ref.watch(debtPaymentRepositoryProvider);
  final bengkelId = ref.watch(bengkelIdProvider);
  if (bengkelId == null) return [];
  return repository.getAll(bengkelId);
});
