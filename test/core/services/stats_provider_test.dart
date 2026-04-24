import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/stats_provider.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/system_providers.dart';
import 'package:servisio_core/core/providers/transaction_providers.dart';
import 'package:servisio_core/core/providers/sale_providers.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import 'package:servisio_core/domain/entities/transaction_item.dart';
import 'package:servisio_core/domain/entities/sale.dart';
import 'package:servisio_core/domain/entities/stok.dart';
import 'package:servisio_core/domain/entities/expense.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeStore fakeStore;

  setUp(() {
    fakeStore = FakeStore();
    SharedPreferences.setMockInitialValues({});
  });

  group('StatsProvider Tests', () {
    test('calculateStats should correctly aggregate data', () async {
      final now = DateTime.now();
      final fakeDb = FakeObjectBoxProvider(fakeStore);
      
      // Transaction today
      final txToday = Transaction(
        customerName: 'Today',
        customerPhone: '123',
        vehicleModel: 'M1',
        vehiclePlate: 'P1',
      );
      txToday.id = 1;
      txToday.createdAt = now.subtract(const Duration(minutes: 10));
      txToday.serviceStatus = ServiceStatus.lunas;
      
      txToday.items.add(TransactionItem(
        name: 'Service', 
        price: 100000, 
        costPrice: 60000, 
        quantity: 1, 
        isService: true
      ));
      txToday.calculateTotals(); // Amount: 100k, Profit: 40k

      // Sale today
      final saleToday = Sale(
        itemName: 'Product', 
        quantity: 1,
        totalPrice: 50000, 
        costPrice: 30000, // Profit: 20k
        createdAt: now
      );

      // Stok items
      final stokLow = Stok(uuid: 'st1', nama: 'Low', jumlah: 2, minStok: 5);
      final stokEmpty = Stok(uuid: 'st2', nama: 'Empty', jumlah: 0, minStok: 1);
      final stokOk = Stok(uuid: 'st3', nama: 'Ok', jumlah: 10, minStok: 5);

      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(fakeDb),
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        ],
      );

      // Populate data BEFORE reading
      fakeDb.transactionBox.put(txToday);
      fakeDb.saleBox.put(saleToday);
      fakeDb.stokBox.putMany([stokLow, stokEmpty, stokOk]);

      // Trigger data load
      container.read(transactionListProvider);
      container.read(saleListProvider);

      final stats = container.read(statsProvider);

      // Assertions
      expect(stats.todayPendapatan, 150000); // 100k + 50k
      expect(stats.todayProfit, 60000); // 40k + 20k
      expect(stats.lowStockCount, 2); // st1 and st2 are both below/at minStok
      expect(stats.emptyStockCount, 1); // Only st2
      expect(stats.totalOrders, 2);
    });

    test('StatsProvider handles weekly and monthly ranges', () async {
      final now = DateTime.now();
      final fakeDb = FakeObjectBoxProvider(fakeStore);
      
      final txRecent = Transaction(
        customerName: 'Recent',
        customerPhone: '123',
        vehicleModel: 'M1',
        vehiclePlate: 'P1',
      );
      txRecent.id = 1;
      txRecent.createdAt = now;
      txRecent.serviceStatus = ServiceStatus.lunas;
      txRecent.items.add(TransactionItem(name: 'Item', price: 100000, costPrice: 50000, quantity: 1));
      txRecent.calculateTotals();
      
      final txWeek = Transaction(
        customerName: 'Weekly',
        customerPhone: '123',
        vehicleModel: 'M1',
        vehiclePlate: 'P1',
      );
      txWeek.id = 2;
      txWeek.createdAt = now.subtract(const Duration(days: 4));
      txWeek.serviceStatus = ServiceStatus.lunas;
      txWeek.items.add(TransactionItem(name: 'Item', price: 50000, costPrice: 20000, quantity: 1));
      txWeek.calculateTotals();

      final txMonth = Transaction(
        customerName: 'Monthly',
        customerPhone: '123',
        vehicleModel: 'M1',
        vehiclePlate: 'P1',
      );
      txMonth.id = 3;
      txMonth.createdAt = now.subtract(const Duration(days: 15));
      txMonth.serviceStatus = ServiceStatus.lunas;
      txMonth.items.add(TransactionItem(name: 'Item', price: 30000, costPrice: 10000, quantity: 1));
      txMonth.calculateTotals();

      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(fakeDb),
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        ],
      );
      
      fakeDb.transactionBox.putMany([txRecent, txWeek, txMonth]);
      
      // Trigger data load
      container.read(transactionListProvider);
      container.read(saleListProvider);
      
      final stats = container.read(statsProvider);
      
      expect(stats.todayPendapatan, 100000);
      expect(stats.weeklyPendapatan, 150000); // 100k + 50k
      expect(stats.monthlyPendapatan, 180000); // 100k + 50k + 30k
    });

    test('calculateStats correctly separates operational vs debt expenses', () {
      final now = DateTime.now();

      // 1. Operational expense hari ini
      final expOps = Expense(
        amount: 50000,
        category: 'LISTRIK',
        bengkelId: 'test-bengkel',
        date: now,
      );

      // 2. Hutang induk (10 hari lalu, belum lunas)
      final parentDebt = Expense(
        amount: 1000000,
        category: 'STOK',
        bengkelId: 'test-bengkel',
        debtStatus: 'HUTANG',
        date: now.subtract(const Duration(days: 10)),
      );
      parentDebt.id = 99;

      // 3. Cicilan hutang hari ini (expense anak — parentExpense.targetId != 0)
      final expDebtPaid = Expense(
        amount: 100000,
        category: 'CICILAN',
        bengkelId: 'test-bengkel',
        date: now,
      );
      expDebtPaid.parentExpense.targetId = 99; // Link ke parentDebt

      final stats = calculateStats(
        [], // transactions
        [], // sales
        [], // stok
        [expOps, parentDebt, expDebtPaid],
      );

      // Expense hari ini: 50k ops + 100k cicilan = 150k
      expect(stats.todayExpense, 150000, reason: 'Total pengeluaran hari ini harus 150.000');
      expect(stats.todayExpenseOperasional, 50000, reason: 'Operasional harus 50.000');
      expect(stats.todayExpenseDebtPaid, 100000, reason: 'Cicilan hutang harus 100.000');

      // Catatan: totalDebt dihitung dari debtBalance pada parentDebt.
      // Dalam unit test (tanpa ObjectBox), backlink `repayments` tidak terisi otomatis,
      // sehingga debtBalance == amount penuh. Logika backlink ditest di expense_test.dart.
      expect(stats.totalDebt, 1000000, reason: 'Hutang induk (tanpa backlink DB) = full amount');
    });

    group('StatsProvider Offline/Edge Cases', () {
      test('StatsProvider returns zero for empty state', () async {
        final fakeDb = FakeObjectBoxProvider(fakeStore);
        final container = ProviderContainer(overrides: [
          dbProvider.overrideWithValue(fakeDb),
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        ]);
        
        container.read(transactionListProvider);
        container.read(saleListProvider);
        
        final stats = container.read(statsProvider);
        expect(stats.todayPendapatan, 0);
        expect(stats.totalOrders, 0);
      });
    });
  });
}
