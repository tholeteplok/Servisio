import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:servislog_core/core/services/bengkel_service.dart';
import 'package:servislog_core/core/sync/sync_telemetry.dart';
import '../../mocks/manual_mocks.dart';

class NullTelemetrySink implements TelemetrySink {
  @override
  void send(SyncEvent event) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BengkelService service;
  late FakeFirebaseFirestore firestore;
  late FakeEncryptionService encryption;
  late FakeDeviceSessionService deviceSession;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    encryption = FakeEncryptionService();
    deviceSession = FakeDeviceSessionService();
    
    // Initialize telemetry with NullSink to avoid path_provider errors
    SyncTelemetry().initialize([NullTelemetrySink()], deviceId: 'test-device');

    service = BengkelService(
      firestore: firestore,
      encryption: encryption,
      deviceSession: deviceSession,
    );
  });

  group('BengkelService Tests', () {
    test('generateBengkelId creates expected format', () {
      final id = service.generateBengkelId('Tentrem Auto');
      expect(id, startsWith('TENTREMAUT-')); // 10 chars max
      expect(id.length, greaterThan(12));
    });

    test('isBengkelIdAvailable returns true if doc missing', () async {
      final available = await service.isBengkelIdAvailable('new-bengkel-id');
      expect(available, isTrue);
    });

    test('claimBengkelId creates bengkel and secret docs', () async {
      const bengkelId = 'TEST-BENGKEL';
      const ownerUid = 'user-1';
      
      await service.claimBengkelId(
        bengkelId: bengkelId,
        ownerUid: ownerUid,
        bengkelName: 'Test Workshop',
        pin: '123456',
      );

      final bengkelDoc = await firestore.collection('bengkel').doc(bengkelId).get();
      expect(bengkelDoc.exists, isTrue);
      expect(bengkelDoc.data()?['name'], equals('Test Workshop'));
      expect(bengkelDoc.data()?['ownerUid'], equals(ownerUid));

      final secretDoc = await firestore.collection('bengkel').doc(bengkelId).collection('secrets').doc('masterKey').get();
      expect(secretDoc.exists, isTrue);
      expect(secretDoc.data()?['value'], startsWith('enc:'));
    });

    test('getWrappedMasterKey retrieves key from secrets sub-collection', () async {
      const bengkelId = 'TEST-BENGKEL';
      await firestore.collection('bengkel').doc(bengkelId).collection('secrets').doc('masterKey').set({
        'value': 'wrapped-key-123',
      });

      final key = await service.getWrappedMasterKey(bengkelId);
      expect(key, equals('wrapped-key-123'));
    });
  });
}
