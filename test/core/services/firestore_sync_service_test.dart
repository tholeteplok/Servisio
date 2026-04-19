import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servislog_core/core/services/firestore_sync_service.dart';
import 'package:servislog_core/domain/entities/transaction.dart' as entity;
import 'package:servislog_core/domain/entities/pelanggan.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FirestoreSyncService service;
  late FakeFirebaseFirestore fakeFirestore;
  late FakeEncryptionService fakeEncryption;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeEncryption = FakeEncryptionService();
    service = FirestoreSyncService(
      firestore: fakeFirestore,
      encryption: fakeEncryption,
    );
  });

  group('FirestoreSyncService', () {
    const bengkelId = 'test-bengkel';

    test('pushTransaction - saves to correct collection', () async {
      final tx = entity.Transaction(
        customerName: 'John Doe',
        customerPhone: '0812',
        vehicleModel: 'Vario',
        vehiclePlate: 'B 1234 ABC',
        uuid: 'tx-uuid',
      );

      await service.pushTransaction(bengkelId, tx);

      final doc = await fakeFirestore
          .collection('bengkel')
          .doc(bengkelId)
          .collection('transactions')
          .doc('tx-uuid')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['customerName'], 'enc:John Doe');
      expect(doc.data()?['syncStatus'], 2);
    });

    test('pushPelanggan - saves encrypted data', () async {
      final p = Pelanggan(
        nama: 'Alice',
        telepon: '0855',
        alamat: 'Jakarta',
        uuid: 'p-uuid',
      );

      await service.pushPelanggan(bengkelId, p);

      final doc = await fakeFirestore
          .collection('bengkel')
          .doc(bengkelId)
          .collection('customers')
          .doc('p-uuid')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'enc:Alice');
    });

    test('pullAllData - fetches multiple collections', () async {
      // Seed data
      await fakeFirestore
          .collection('bengkel')
          .doc(bengkelId)
          .collection('customers')
          .doc('c1')
          .set({'uuid': 'c1', 'name': 'enc:Customer 1'});

      final result = await service.pullAllData(bengkelId);

      expect(result['customers'], isNotEmpty);
      expect(result['customers']![0]['name'], 'Customer 1');
    });

    test('mergeData - remote wins if newer', () {
      final now = DateTime.now();
      final local = {
        'updatedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
        'val': 'local'
      };
      final remote = {
        'updatedAt': Timestamp.fromDate(now),
        'val': 'remote'
      };

      final merged = service.mergeData(local, remote);
      expect(merged['val'], 'remote');
    });
  });
}
