import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../objectbox.g.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/stok_history.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/sync_queue_item.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/debt_payment.dart';

class ObjectBoxProvider {
  late final Store _store;
  late final Box<Transaction> _transactionBox;
  late final Box<Pelanggan> _pelangganBox;
  late final Box<Stok> _stokBox;
  late final Box<Sale> _saleBox;
  late final Box<StokHistory> _stokHistoryBox;
  late final Box<Staff> _staffBox;
  late final Box<Vehicle> _vehicleBox;
  late final Box<SyncQueueItem> _syncQueueBox;
  late final Box<Expense> _expenseBox;
  late final Box<ExpenseCategory> _expenseCategoryBox;
  late final Box<Supplier> _supplierBox;
  late final Box<DebtPayment> _debtPaymentBox;

  Box<Transaction> get transactionBox => _transactionBox;
  Box<Pelanggan> get pelangganBox => _pelangganBox;
  Box<Stok> get stokBox => _stokBox;
  Box<Sale> get saleBox => _saleBox;
  Box<StokHistory> get stokHistoryBox => _stokHistoryBox;
  Box<Staff> get staffBox => _staffBox;
  Box<Vehicle> get vehicleBox => _vehicleBox;
  Box<SyncQueueItem> get syncQueueBox => _syncQueueBox;
  Box<Expense> get expenseBox => _expenseBox;
  Box<ExpenseCategory> get expenseCategoryBox => _expenseCategoryBox;
  Box<Supplier> get supplierBox => _supplierBox;
  Box<DebtPayment> get debtPaymentBox => _debtPaymentBox;
  Store get store => _store;

  ObjectBoxProvider._create(this._store) {
    _transactionBox = Box<Transaction>(_store);
    _pelangganBox = Box<Pelanggan>(_store);
    _stokBox = Box<Stok>(_store);
    _saleBox = Box<Sale>(_store);
    _stokHistoryBox = Box<StokHistory>(_store);
    _staffBox = Box<Staff>(_store);
    _vehicleBox = Box<Vehicle>(_store);
    _syncQueueBox = Box<SyncQueueItem>(_store);
    _expenseBox = Box<Expense>(_store);
    _expenseCategoryBox = Box<ExpenseCategory>(_store);
    _supplierBox = Box<Supplier>(_store);
    _debtPaymentBox = Box<DebtPayment>(_store);
  }

  static Future<ObjectBoxProvider> create() async {
    final store = await openStore(); // Default directory
    return ObjectBoxProvider._create(store);
  }

  void dispose() {
    _store.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

class DbInstanceNotifier extends AsyncNotifier<ObjectBoxProvider> {
  @override
  FutureOr<ObjectBoxProvider> build() async {
    final provider = await ObjectBoxProvider.create();
    ref.onDispose(() => provider.dispose());
    return provider;
  }

  Future<void> setInstance(ObjectBoxProvider newInstance) async {
    state = AsyncData(newInstance);
  }
}

final dbInstanceProvider = AsyncNotifierProvider<DbInstanceNotifier, ObjectBoxProvider>(() {
  return DbInstanceNotifier();
});

final dbProvider = Provider<ObjectBoxProvider>((ref) {
  final asyncInstance = ref.watch(dbInstanceProvider);
  return asyncInstance.maybeWhen(
    data: (instance) => instance,
    orElse: () => throw UnimplementedError(
      'dbProvider accessed before initialization. Watch dbInstanceProvider first.',
    ),
  );
});
