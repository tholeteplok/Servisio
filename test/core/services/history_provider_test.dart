import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/history_provider.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import 'package:servisio_core/domain/entities/sale.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;

  setUp(() {
    fakeDb = FakeObjectBoxProvider();
    container = createContainer(
      overrides: [
        dbProvider.overrideWithValue(fakeDb),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('HistoryList Provider Tests', () {
    test('HistoryList should merge Transactions and Sales correctly', () async {
      final now = DateTime.now();
      
      // Seed 1 paid transaction
      final tx = Transaction(
        uuid: 'tx-paid',
        trxNumber: 'TX-001',
        customerName: 'Budi',
        customerPhone: '08123',
        vehicleModel: 'Vario',
        vehiclePlate: 'B 1234',
      )
        ..totalAmount = 150000
        ..serviceStatus = ServiceStatus.lunas
        ..createdAt = now;
      fakeDb.transactionBox.put(tx);

      // Seed 1 unpaid transaction (should NOT be in history)
      final txUnpaid = Transaction(
        uuid: 'tx-unpaid',
        trxNumber: 'TX-002',
        customerName: 'Ani',
        customerPhone: '08124',
        vehicleModel: 'Beat',
        vehiclePlate: 'B 5678',
      )
        ..totalAmount = 50000
        ..serviceStatus = ServiceStatus.antri
        ..createdAt = now;
      fakeDb.transactionBox.put(txUnpaid);

      // Seed 1 sale
      final sale = Sale(
        uuid: 'sale-1',
        itemName: 'Oli MPX',
        quantity: 1,
        totalPrice: 45000,
        createdAt: now.add(const Duration(minutes: 5)), // Newer
      );
      fakeDb.saleBox.put(sale);

      final state = container.read(historyListProvider);

      // Should have 2 items (sale-1 and tx-paid)
      expect(state.items.length, 2);
      
      // Sorted by date (newest first)
      expect(state.items.first.id, 'sale-1');
      expect(state.items.last.id, 'tx-paid');
      
      expect(state.items.first.type, 'SALE');
      expect(state.items.last.type, 'SERVICE');
    });

    test('HistoryFilter should correctly filter by type', () async {
      final now = DateTime.now();
      final tx = Transaction(
        uuid: 'tx-1',
        trxNumber: 'TX-001',
        customerName: 'Budi',
        customerPhone: '08123',
        vehicleModel: 'Vario',
        vehiclePlate: 'B 1234',
      )
        ..totalAmount = 100000
        ..serviceStatus = ServiceStatus.lunas
        ..createdAt = now;
      fakeDb.transactionBox.put(tx);
      
      fakeDb.saleBox.put(Sale(
        uuid: 'sale-1',
        itemName: 'Oli',
        quantity: 1,
        totalPrice: 50000,
        createdAt: now,
      ));

      // Filter for SERVICE only
      container.read(historyFilterNotifierProvider.notifier).updateFilter(type: 'SERVICE');
      
      var state = container.read(historyListProvider);
      expect(state.items.every((item) => item.type == 'SERVICE'), isTrue);
      expect(state.items.length, 1);

      // Filter for SALE only
      container.read(historyFilterNotifierProvider.notifier).updateFilter(type: 'SALE');
      state = container.read(historyListProvider);
      expect(state.items.every((item) => item.type == 'SALE'), isTrue);
      expect(state.items.length, 1);
    });
  });
}
