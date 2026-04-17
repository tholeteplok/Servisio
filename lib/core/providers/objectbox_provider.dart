import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../objectbox.g.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/stok_history.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/sync_queue_item.dart';

part 'objectbox_provider.g.dart';

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

  Box<Transaction> get transactionBox => _transactionBox;
  Box<Pelanggan> get pelangganBox => _pelangganBox;
  Box<Stok> get stokBox => _stokBox;
  Box<Sale> get saleBox => _saleBox;
  Box<StokHistory> get stokHistoryBox => _stokHistoryBox;
  Box<Staff> get staffBox => _staffBox;
  Box<Vehicle> get vehicleBox => _vehicleBox;
  Box<SyncQueueItem> get syncQueueBox => _syncQueueBox;
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
  }

  static Future<ObjectBoxProvider> create() async {
    final store = await openStore(); // Default directory
    return ObjectBoxProvider._create(store);
  }
}

// ── Database Initialization & Swapping ──

/// Provider that manages the ObjectBox instance.
/// It uses [Future] for initial setup and can be updated at runtime.
@Riverpod(keepAlive: true)
class DbInstance extends _$DbInstance {
  @override
  FutureOr<ObjectBoxProvider> build() async {
    // Initial creation. 
    // If already initialized in main.dart and passed here, we could optimize,
    // but building it here is cleaner for testability.
    return await ObjectBoxProvider.create();
  }

  /// Manually update the database instance (e.g. after a restore operation).
  void setInstance(ObjectBoxProvider newInstance) {
    state = AsyncData(newInstance);
  }
}

/// Global provider for application logic.
/// WARNING: This should only be accessed when [dbInstanceProvider] is ready.
final dbProvider = Provider<ObjectBoxProvider>((ref) {
  final asyncInstance = ref.watch(dbInstanceProvider);
  return asyncInstance.maybeWhen(
    data: (instance) => instance,
    orElse: () => throw UnimplementedError(
      'dbProvider accessed before initialization. Watch dbInstanceProvider first.',
    ),
  );
});

// Since the store closure is critical, we should ensure the ObjectBoxProvider 
// instance itself is capable of closing.
extension ObjectBoxProviderExtension on ObjectBoxProvider {
  void dispose() {
    _store.close();
  }
}
