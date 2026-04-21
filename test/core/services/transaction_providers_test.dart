import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/transaction_providers.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import 'package:servisio_core/data/repositories/transaction_repository.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

class FakeTransactionRepository extends Fake implements TransactionRepository {
  final List<Transaction> _transactions = [];

  @override
  List<Transaction> getAll({int limit = 0, int offset = 0, ServiceStatus? filterStatus, String? searchQuery}) {
    return _transactions.where((t) => !t.isDeleted).toList();
  }

  @override
  int save(Transaction transaction) {
    if (transaction.id == 0) {
      transaction.id = _transactions.length + 1;
    }
    final existingIndex = _transactions.indexWhere((t) => t.id == transaction.id);
    if (existingIndex >= 0) {
      _transactions[existingIndex] = transaction;
    } else {
      _transactions.add(transaction);
    }
    return transaction.id;
  }

  @override
  bool softDelete(int id) {
    final t = _transactions.firstWhere((t) => t.id == id, orElse: () => Transaction(customerName: '', customerPhone: '', vehicleModel: '', vehiclePlate: ''));
    if (t.uuid.isNotEmpty) {
      t.isDeleted = true;
      return true;
    }
    return false;
  }
}

void main() {
  late ProviderContainer container;
  late FakeTransactionRepository fakeRepository;
  late FakeSyncWorker fakeSyncWorker;
  late FakeObjectBoxProvider fakeDb;

  setUp(() {
    fakeRepository = FakeTransactionRepository();
    fakeSyncWorker = FakeSyncWorker();
    fakeDb = FakeObjectBoxProvider();

    container = createContainer(
      overrides: [
        transactionRepositoryProvider.overrideWith((ref) => fakeRepository),
        syncWorkerProvider.overrideWith((ref) => fakeSyncWorker),
        dbProvider.overrideWith((ref) => fakeDb),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('TransactionListNotifier Tests', () {
    test('Initial loading fetches all transactions', () async {
      fakeRepository.save(Transaction(customerName: 'A', customerPhone: '0', vehicleModel: 'V', vehiclePlate: '1', uuid: 'tx-1'));
      
      final sub = container.listen(transactionListProvider, (_, __) {});
      
      // Give async provider time to set state if needed
      await Future.delayed(Duration.zero);
      final state = container.read(transactionListProvider).value;
      expect(state?.length, 1);
      sub.close();
    });

    test('addTransaction saves to repo and enqueues sync', () async {
      final tx = Transaction(customerName: 'A', customerPhone: '0', vehicleModel: 'V', vehiclePlate: '1', uuid: 'tx-2');
      
      await container.read(transactionListProvider.notifier).addTransaction(tx);
      
      final items = fakeRepository.getAll();
      expect(items.length, 1);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'tx-2'), isTrue);
    });

    test('deleteTransaction performs soft delete', () async {
      final tx = Transaction(customerName: 'A', customerPhone: '0', vehicleModel: 'V', vehiclePlate: '1', uuid: 'tx-3');
      fakeRepository.save(tx);
      
      await container.read(transactionListProvider.notifier).deleteTransaction(tx.id, tx.uuid);
      
      final items = fakeRepository.getAll();
      expect(items.isEmpty, isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'tx-3'), isTrue);
    });
  });
}
