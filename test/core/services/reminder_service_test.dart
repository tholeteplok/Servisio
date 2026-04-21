import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/reminder_provider.dart';
import 'package:servisio_core/core/providers/transaction_providers.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/system_providers.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_utils.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late ProviderContainer container;
  late FakeObjectBoxProvider fakeDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeDb = FakeObjectBoxProvider();
    final prefs = await SharedPreferences.getInstance();
    container = createContainer(
      overrides: [
        dbProvider.overrideWithValue(fakeDb),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ReminderProvider Tests', () {
    test('reminderTransactions should return only due soon and lunas transactions', () async {
      final now = DateTime.now();
      
      // Transaction 1: Lunas and Due Soon (3 days from now, threshold is 7)
      final tx1 = Transaction(
        uuid: 'tx-1',
        trxNumber: 'TX001',
        customerName: 'Customer 1',
        customerPhone: '081',
        vehicleModel: 'Motor 1',
        vehiclePlate: 'B 1',
        recommendationTimeMonth: 1, // Will set nextServiceDate to 30 days after createdAt
      )..serviceStatus = ServiceStatus.lunas;
      
      // Manually adjust createdAt to control nextServiceDate
      tx1.createdAt = now.subtract(const Duration(days: 27)); // nextServiceDate = now + 3 days
      // Need to set vehicle/customer targets if logic uses them
      // In reminder_provider.dart: final key = "${customerId}_$vehicleId";
      // So we need to put them in the box or just set targetIds
      tx1.vehicle.targetId = 1;
      tx1.pelanggan.targetId = 1;

      // Transaction 2: Antri (Should be ignored)
      final tx2 = Transaction(
        uuid: 'tx-2',
        trxNumber: 'TX002',
        customerName: 'Customer 2',
        customerPhone: '082',
        vehicleModel: 'Motor 2',
        vehiclePlate: 'B 2',
        recommendationTimeMonth: 1,
      )..serviceStatus = ServiceStatus.antri;
      
      tx2.createdAt = now.subtract(const Duration(days: 29)); // nextServiceDate = now + 1 day
      tx2.vehicle.targetId = 2;
      tx2.pelanggan.targetId = 2;

      // Transaction 3: Lunas but Not Due (15 days from now)
      final tx3 = Transaction(
        uuid: 'tx-3',
        trxNumber: 'TX003',
        customerName: 'Customer 3',
        customerPhone: '083',
        vehicleModel: 'Motor 3',
        vehiclePlate: 'B 3',
        recommendationTimeMonth: 2,
      )..serviceStatus = ServiceStatus.lunas;
      
      tx3.createdAt = now.subtract(const Duration(days: 45)); // nextServiceDate = now + 15 days
      tx3.vehicle.targetId = 3;
      tx3.pelanggan.targetId = 3;

      fakeDb.transactionBox.putMany([tx1, tx2, tx3]);

      // Ensure data is loaded
      final list = container.read(transactionListProvider).value!;
      expect(list.length, 3, reason: 'Total transactions should be 3');
      
      final reminders = container.read(reminderTransactionsProvider);
      
      expect(reminders.length, 1, reason: 'Should have 1 reminder (tx1)');
      expect(reminders.first.uuid, 'tx-1');
    });

    test('reminderTransactions should take only the newest transaction per vehicle', () async {
      final now = DateTime.now();
      
      // Older transaction for vehicle 1
      final txOld = Transaction(
        uuid: 'tx-old',
        customerName: 'C10',
        customerPhone: '10',
        vehicleModel: 'M10',
        vehiclePlate: 'P10',
        recommendationTimeMonth: 1,
      )..serviceStatus = ServiceStatus.lunas;
      txOld.createdAt = now.subtract(const Duration(days: 60)); // nextServiceDate = now - 30 days (overdue)
      txOld.vehicle.targetId = 10;
      txOld.pelanggan.targetId = 10;

      // Newer transaction for vehicle 1
      final txNew = Transaction(
        uuid: 'tx-new',
        customerName: 'C10',
        customerPhone: '10',
        vehicleModel: 'M10',
        vehiclePlate: 'P10',
        recommendationTimeMonth: 2,
      )..serviceStatus = ServiceStatus.lunas;
      txNew.createdAt = now.subtract(const Duration(days: 5)); // nextServiceDate = now + 55 days
      txNew.vehicle.targetId = 10;
      txNew.pelanggan.targetId = 10;

      fakeDb.transactionBox.putMany([txOld, txNew]);

      // Ensure data is loaded
      final list = container.read(transactionListProvider).value!;
      expect(list.length, 2, reason: 'Total transactions should be 2');

      final reminders = container.read(reminderTransactionsProvider);
      
      // Even though txOld is overdue, txNew is the LATEST record for this vehicle.
      // And txNew is NOT due. So reminders should be empty.
      expect(reminders.isEmpty, isTrue, reason: 'Reminders should be empty because latest tx is not due');
    });
  });
}
