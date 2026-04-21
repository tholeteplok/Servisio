import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/device_session_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late DeviceSessionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true);
    service = DeviceSessionService(
      firestore: firestore,
      auth: auth,
      encryption: FakeEncryptionService(),
    );
  });

  group('DeviceSessionService Tests', () {
    test('getOrCreateDeviceId() should persist ID', () async {
      final id1 = await service.getOrCreateDeviceId();
      final id2 = await service.getOrCreateDeviceId();
      expect(id1, id2);
      expect(id1, isNotEmpty);
    });

    test('registerDevice() should create user doc in Firestore', () async {
      const userId = 'user-123';
      await service.registerDevice(userId);
      
      final doc = await firestore.collection('users').doc(userId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['activeDeviceId'], isNotNull);
      expect(doc.data()!['loginHistory'], isNotEmpty);
    });

    test('watchSessionValidity() should detect displaced session', () async {
      const userId = 'user-123';
      await service.getOrCreateDeviceId();

      // Register me
      await service.registerDevice(userId);
      
      final stream = service.watchSessionValidity(userId);
      final events = <DeviceSessionStatus>[];
      
      // Keep subscription alive
      final sub = stream.listen(events.add);
      
      // Let initial fetch complete
      await Future.delayed(const Duration(milliseconds: 100));
      expect(events.first, DeviceSessionStatus.valid);
      
      // Simulate another device login
      await firestore.collection('users').doc(userId).update({
        'activeDeviceId': 'other-device-id',
      });
      
      // Wait for snapshot
      await Future.delayed(const Duration(milliseconds: 100));
      expect(events.last, DeviceSessionStatus.displaced);
      
      await sub.cancel();
    });

    test('requestRemoteWipe() should set flag', () async {
      const userId = 'user-123';
      await service.requestRemoteWipe(userId);
      
      final doc = await firestore.collection('users').doc(userId).get();
      expect(doc.data()!['pendingRemoteWipe'], isTrue);
    });
  });
}
