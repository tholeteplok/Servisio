import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/core/services/device_session_service.dart';
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
      final myId = await service.getOrCreateDeviceId();
      
      // Register me
      await service.registerDevice(userId);
      
      final stream = service.watchSessionValidity(userId);
      
      // Initially valid
      expect(await stream.first, DeviceSessionStatus.valid);
      
      // Simulate another device login
      await firestore.collection('users').doc(userId).update({
        'activeDeviceId': 'other-device-id',
      });
      
      // Should emit displaced
      // Note: In fake_cloud_firestore, snapshots might need a tick
      final status = await stream.skip(1).first;
      expect(status, DeviceSessionStatus.displaced);
    });

    test('requestRemoteWipe() should set flag', () async {
      const userId = 'user-123';
      await service.requestRemoteWipe(userId);
      
      final doc = await firestore.collection('users').doc(userId).get();
      expect(doc.data()!['pendingRemoteWipe'], isTrue);
    });
  });
}
