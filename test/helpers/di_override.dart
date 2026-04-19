import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servislog_core/core/services/encryption_service.dart';
import 'package:servislog_core/core/services/session_manager.dart';
import 'package:servislog_core/core/services/device_session_service.dart';
import '../mocks/manual_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Collection of default overrides for unit testing.
List<Override> getBaseTestOverrides({
  FakeFlutterSecureStorage? secureStorage,
  MockFirebaseAuth? auth,
  FakeFirebaseFirestore? firestore,
  EncryptionService? encryptionService,
  DeviceSessionService? deviceSessionService,
  FakeHttpClient? httpClient,
  FakeConnectivity? connectivity,
}) {
  final storage = secureStorage ?? FakeFlutterSecureStorage();
  return [
    secureStorageProvider.overrideWithValue(storage),
    firebaseAuthProvider.overrideWithValue(auth ?? MockFirebaseAuth()),
    firestoreProvider.overrideWithValue(firestore ?? FakeFirebaseFirestore()),
    encryptionServiceProvider.overrideWith((ref) => encryptionService ?? EncryptionService(secureStorage: storage)),
    deviceSessionServiceProvider.overrideWith((ref) => deviceSessionService ?? FakeDeviceSessionService()),
    httpClientProvider.overrideWithValue(httpClient ?? FakeHttpClient()),
    connectivityProvider.overrideWithValue(connectivity ?? FakeConnectivity()),
  ];
}
