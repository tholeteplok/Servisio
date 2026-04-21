import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/transaction_providers.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;
  late FakeSyncWorker fakeSyncWorker;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();
    fakeSyncWorker = FakeSyncWorker();

    container = createContainer(
      overrides: [
        dbProvider.overrideWithValue(fakeDb),
        syncWorkerProvider.overrideWithValue(fakeSyncWorker),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('TransactionList Provider Tests', () {
    test('Initial state should load transactions from repository', () async {
      final box = fakeDb.transactionBox;
      box.put(Transaction(
        trxNumber: 'TX-001',
        uuid: 'tx-1',
        customerName: 'Test',
        customerPhone: '0812',
        vehicleModel: 'Vario',
        vehiclePlate: 'B 1234',
      ));

      final list = container.read(transactionListProvider).value!;
      
      expect(list.length, 1);
      expect(list.first.trxNumber, 'TX-001');
    });

    test('addTransaction() should update state and enqueue sync', () async {
      final tx = Transaction(
        trxNumber: 'TX-002',
        uuid: 'tx-2',
        customerName: 'Test 2',
        customerPhone: '0855',
        vehicleModel: 'Beat',
        vehiclePlate: 'B 5678',
      );
      
      await container.read(transactionListProvider.notifier).addTransaction(tx);
      
      final list = container.read(transactionListProvider).value;
      expect(list?.any((t) => t.trxNumber == 'TX-002'), isTrue);
      expect(fakeSyncWorker.enqueuedItems.any((e) => e['entityUuid'] == 'tx-2'), isTrue);
    });
  });
}
