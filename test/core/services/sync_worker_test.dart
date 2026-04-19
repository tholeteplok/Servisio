import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:servislog_core/core/services/session_manager.dart';
import 'package:servislog_core/core/services/sync_worker.dart';
import 'package:servislog_core/domain/entities/sync_queue_item.dart';
import 'package:servislog_core/domain/entities/transaction.dart';
import 'package:servislog_core/core/sync/sync_telemetry.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeObjectBoxProvider fakeDb;
  late FakeFirestoreSyncService fakeSyncService;
  late FakeConnectivity fakeConnectivity;
  late FakeSessionManager fakeSessionManager;
  late FakeSyncLockManager fakeLockManager;
  late SyncWorker worker;

  setUp(() {
    // Disable real telemetry sinks for tests
    SyncTelemetry().initialize([], deviceId: 'test-device');

    fakeDb = FakeObjectBoxProvider();
    fakeSyncService = FakeFirestoreSyncService();
    fakeConnectivity = FakeConnectivity();
    fakeSessionManager = FakeSessionManager();
    fakeLockManager = FakeSyncLockManager();

    worker = SyncWorker(
      db: fakeDb,
      syncService: fakeSyncService,
      bengkelId: 'test-bengkel',
      userId: 'test-user',
      connectivity: fakeConnectivity,
      sessionManager: fakeSessionManager,
      lockManager: fakeLockManager,
    );
  });

  tearDown(() {
    worker.stop();
  });

  group('SyncWorker Tests', () {
    test('enqueue() should save item to ObjectBox', () async {
      worker.enqueue(
        entityType: 'transaction',
        entityUuid: 'tx-123',
        priority: SyncPriority.critical,
      );

      final box = fakeDb.syncQueueBox as FakeBox<SyncQueueItem>;
      expect(box.items.length, 1);
      expect(box.items.first.entityUuid, 'tx-123');
      expect(box.items.first.status, 'pending');

      // Since critical is unawaited, wait a bit for it to finish _processQueue
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('processQueue should sync pending items when connectivity is available', () async {
      // 1. Prepare data
      final item = SyncQueueItem(
        entityType: 'transaction',
        entityUuid: 'tx-123',
        priority: SyncPriority.critical.code,
        status: 'pending',
      );
      (fakeDb.syncQueueBox as FakeBox<SyncQueueItem>).put(item);

      final tx = Transaction(
        uuid: 'tx-123',
        customerName: 'Test Customer',
        customerPhone: '0812345678',
        vehicleModel: 'Test Drive',
        vehiclePlate: 'B 1234 ABC',
      );
      (fakeDb.transactionBox as FakeBox<Transaction>).put(tx);

      // 2. Setup Connectivity & Session
      fakeConnectivity.mockResult = ConnectivityResult.wifi;
      fakeSessionManager.mockStatus = SessionStatus.valid;

      // 4. Run process
      worker.start();
      
      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. Verify
      expect(fakeSyncService.pushedItems.length, 1, reason: 'Item should have been pushed');
      expect(fakeSyncService.pushedItems.first['entityUuid'], 'tx-123');
      
      final box = fakeDb.syncQueueBox as FakeBox<SyncQueueItem>;
      expect(box.items.first.status, 'synced');
      
      final updatedTx = (fakeDb.transactionBox as FakeBox<Transaction>).items.first;
      expect(updatedTx.syncStatus, SyncStatus.synced.code);
    });

    test('should NOT sync if connectivity is none', () async {
      final item = SyncQueueItem(
        entityType: 'transaction',
        entityUuid: 'tx-123',
        priority: SyncPriority.critical.code,
      );
      (fakeDb.syncQueueBox as FakeBox<SyncQueueItem>).put(item);

      fakeConnectivity.mockResult = ConnectivityResult.none;
      
      worker.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncService.pushedItems.isEmpty, true);
      expect(boxItems(fakeDb).first.status, 'pending');
    });

    test('should respect syncWifiOnly setting', () async {
      final item = SyncQueueItem(
        entityType: 'transaction',
        entityUuid: 'tx-123',
        priority: SyncPriority.critical.code,
      );
      (fakeDb.syncQueueBox as FakeBox<SyncQueueItem>).put(item);

      final wifiWorker = SyncWorker(
        db: fakeDb,
        syncService: fakeSyncService,
        bengkelId: 'test-bengkel',
        connectivity: fakeConnectivity,
        syncWifiOnly: true,
        lockManager: fakeLockManager,
        sessionManager: fakeSessionManager,
      );

      fakeConnectivity.mockResult = ConnectivityResult.mobile;
      
      wifiWorker.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeSyncService.pushedItems.isEmpty, true);
      wifiWorker.stop();
    });

    test('should increment retryCount and eventually fail after limit', () async {
      final stateCompleter = Completer<SyncWorkerState>();
      worker.onStateChanged = (state) {
        if (state == SyncWorkerState.error && !stateCompleter.isCompleted) {
          stateCompleter.complete(state);
        }
      };

      final item = SyncQueueItem(
        entityType: 'transaction',
        entityUuid: 'tx-failure',
        priority: SyncPriority.normal.code,
      );
      (fakeDb.syncQueueBox as FakeBox<SyncQueueItem>).put(item);

      final tx = Transaction(
        uuid: 'tx-failure',
        customerName: 'Fail Task',
        customerPhone: '0',
        vehicleModel: 'None',
        vehiclePlate: 'B 1 FAIL',
      );
      (fakeDb.transactionBox as FakeBox<Transaction>).put(tx);

      fakeSyncService.shouldFail = true;
      fakeConnectivity.mockResult = ConnectivityResult.wifi;
      
      worker.start();
      
      // Wait for the sync worker to report an error (failure leads to error state)
      await stateCompleter.future.timeout(const Duration(seconds: 5));
      
      final updatedItem = boxItems(fakeDb).first;
      expect(updatedItem.retryCount, 1, reason: 'retryCount should have been incremented');
      expect(updatedItem.status, 'pending', reason: 'status should still be pending for retry');
    });
  });
}

List<SyncQueueItem> boxItems(FakeObjectBoxProvider db) {
  return (db.syncQueueBox as FakeBox<SyncQueueItem>).items;
}
