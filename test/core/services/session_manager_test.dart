import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:servislog_core/core/services/session_manager.dart';
import '../../mocks/manual_mocks.dart';
import '../../helpers/test_utils.dart';
import '../../helpers/di_override.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('SessionManager Tests', () {
    late ProviderContainer container;
    late FakeFlutterSecureStorage fakeSecureStorage;
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late FakeDeviceSessionService fakeDeviceService;
    late FakeHttpClient fakeHttpClient;
    late FakeConnectivity fakeConnectivity;
    late SessionManager sessionManager;

    setUp(() {
      fakeSecureStorage = FakeFlutterSecureStorage();
      mockAuth = MockFirebaseAuth(signedIn: true);
      mockFirestore = FakeFirebaseFirestore();

      fakeDeviceService = FakeDeviceSessionService();
      fakeHttpClient = FakeHttpClient();
      fakeConnectivity = FakeConnectivity();

      container = createContainer(
        overrides: getBaseTestOverrides(
          secureStorage: fakeSecureStorage,
          auth: mockAuth,
          firestore: mockFirestore,
          deviceSessionService: fakeDeviceService,
          httpClient: fakeHttpClient,
          connectivity: fakeConnectivity,
        ),
      );

      sessionManager = container.read(sessionManagerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    group('Master Password Verification', () {
      test('verifyMasterPassword returns false when no password saved', () async {
        final result = await sessionManager.verifyMasterPassword('123456');
        expect(result, isFalse);
      });

      test('verifyMasterPassword returns true for correct unsalted password (legacy)', () async {
        const pin = '123456';
        final hash = sha256.convert(utf8.encode(pin)).toString();
        
        await fakeSecureStorage.write(key: SessionPolicy.masterPasswordKey, value: hash);

        final result = await sessionManager.verifyMasterPassword(pin);
        expect(result, isTrue);
      });

      test('verifyMasterPassword returns true for correct salted password', () async {
        const pin = '123456';
        const salt = 'test_salt';
        final saltBytes = utf8.encode(salt);
        final pinBytes = utf8.encode(pin);
        final hash = sha256.convert([...saltBytes, ...pinBytes]).toString();
        
        await fakeSecureStorage.write(
          key: SessionPolicy.masterPasswordKey, 
          value: '$salt:$hash',
        );

        final result = await sessionManager.verifyMasterPassword(pin);
        expect(result, isTrue);
      });
    });

    group('Session Management', () {
      const dummyToken = 'header.eyJleHAiOiAyNTEyODU5NDAwfQ==.signature'; // Exp: 2049
      const userId = 'user_123';
      const role = 'owner';
      const bengkelId = 'bengkel_456';

      test('saveSession correctly writes metadata to secure storage', () async {
        await sessionManager.saveSession(
          token: dummyToken,
          userId: userId,
          role: role,
          bengkelId: bengkelId,
        );

        expect(await fakeSecureStorage.read(key: 'user_id'), userId);
        expect(await fakeSecureStorage.read(key: 'user_role'), role);
        expect(await fakeSecureStorage.read(key: 'bengkel_id'), bengkelId);
      });

      test('clearSession removes all metadata and signs out', () async {
        await fakeSecureStorage.write(key: 'user_id', value: userId);
        await sessionManager.clearSession();

        expect(await fakeSecureStorage.read(key: 'user_id'), isNull);
        expect(mockAuth.currentUser, isNull);
      });
    });

    group('Device Fingerprint & Handshake', () {
      test('_handshakeOnline sends correct device fingerprint', () async {
        // 1. Setup mock user with token
        final mockUser = MockUser(uid: 'user_123');
        mockAuth.mockUser = mockUser;
        
        // 2. Setup mock device info
        const deviceId = 'fingerprint_abc_123';
        fakeDeviceService.deviceId = deviceId;

        // 3. Set Connectivity (Online)
        fakeConnectivity.mockResult = ConnectivityResult.wifi;

        // 4. Trigger validation
        await sessionManager.validateSession();

        // 5. Verify fingerprint was sent in the body
        expect(fakeHttpClient.lastBody, isNotNull);
        expect(fakeHttpClient.lastBody.toString(), contains(deviceId));
      });
    });
  });
}
