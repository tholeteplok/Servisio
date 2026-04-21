import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/migration_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MigrationService service;
  
  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = MigrationService(
      firestore: firestore,
      encryption: FakeEncryptionService(),
    );
  });

  group('MigrationService Tests', () {
    test('migrateToEncryption() should encrypt unencrypted docs', () async {
      const bengkelId = 'b-1';
      
      // Seed data
      await firestore.collection('bengkel').doc(bengkelId).collection('customers').add({
        'name': 'Budi',
        'isEncrypted': false,
      });
      
      await service.migrateToEncryption(bengkelId);
      
      // Verify
      final snapshot = await firestore.collection('bengkel').doc(bengkelId).collection('customers').get();
      expect(snapshot.docs.first.data()['isEncrypted'], isTrue);
      // FakeEncryptionService prefixes with 'enc:'
      expect(snapshot.docs.first.data()['name'], startsWith('enc:'));
    });

    test('migration checkpoint prevents redundant work', () async {
       const bengkelId = 'b-1';
       
       // Mark as completed in checkpoint
       await firestore
          .collection('bengkel')
          .doc(bengkelId)
          .collection('_internal')
          .doc('migration_status')
          .set({
            'completedCollections': ['customers']
          });

      // Seed data (which should be skipped)
      await firestore.collection('bengkel').doc(bengkelId).collection('customers').add({
        'name': 'Budi',
        'isEncrypted': false,
      });
      
      await service.migrateToEncryption(bengkelId);
      
      // Verify NOT encrypted
      final snapshot = await firestore.collection('bengkel').doc(bengkelId).collection('customers').get();
      expect(snapshot.docs.first.data()['isEncrypted'], isFalse);
    });
  });
}
