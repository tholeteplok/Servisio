import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
// Note: ObjectBox exports Transaction, but it can be hidden if needed. 
// If analyze says it doesn't export it, we remove the 'hide'.
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/services/document_service.dart';
import 'package:servisio_core/core/services/device_session_service.dart';
import 'package:servisio_core/core/services/encryption_service.dart';
import 'package:servisio_core/core/services/auth_service.dart';
import 'package:servisio_core/core/services/sync_worker.dart';
import 'package:servisio_core/core/services/session_manager.dart';
import 'package:servisio_core/core/sync/sync_lock_manager.dart';

import 'package:pdf/pdf.dart';
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:typed_data';
import 'package:servisio_core/domain/entities/transaction.dart';
import 'package:servisio_core/domain/entities/pelanggan.dart';
import 'package:servisio_core/domain/entities/stok.dart';
import 'package:servisio_core/domain/entities/staff.dart';
import 'package:servisio_core/domain/entities/vehicle.dart';
import 'package:servisio_core/domain/entities/stok_history.dart';
import 'package:servisio_core/domain/entities/service_master.dart';
import 'package:servisio_core/domain/entities/sync_queue_item.dart';
import 'package:servisio_core/domain/entities/sale.dart';
import 'package:servisio_core/domain/entities/expense.dart';
import 'package:servisio_core/domain/entities/debt_payment.dart';
import 'package:servisio_core/core/services/firestore_sync_service.dart';
import 'package:servisio_core/objectbox.g.dart';

// ── Device Info Mocks ────────────────────────────────────────

// ignore: must_be_immutable
class MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {
  @override
  String get id => 'android-test-id';
  @override
  String get model => 'Test Model';
  @override
  String get brand => 'Test Brand';
}

// ignore: must_be_immutable
class MockIosDeviceInfo extends Mock implements IosDeviceInfo {
  @override
  String get identifierForVendor => 'ios-test-id';
  @override
  String get name => 'Test iPhone';
  @override
  String get systemVersion => '15.0';
}

class FakeDeviceInfoPlugin extends Fake implements DeviceInfoPlugin {
  @override
  Future<AndroidDeviceInfo> get androidInfo async => MockAndroidDeviceInfo();
  @override
  Future<IosDeviceInfo> get iosInfo async => MockIosDeviceInfo();
}

// manual_mocks.dart provides mocks that don't depend on build_runner.

/// A robust fake for FlutterSecureStorage that avoids Mockito internal errors.
typedef FakeSecureStorage = FakeFlutterSecureStorage;

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }
}
// FakeFirebaseAuth removed in favor of MockFirebaseAuth from firebase_auth_mocks

class FakeConnectivity extends Fake implements Connectivity {
  ConnectivityResult mockResult = ConnectivityResult.wifi;
  
  @override
  Future<ConnectivityResult> checkConnectivity() async => mockResult;
  
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => Stream.value(mockResult);
}
class FakeHttpClient extends Fake implements http.Client {
  http.Response? mockResponse;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  Object? lastBody;

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;
    return mockResponse ?? http.Response('{"status": "ok"}', 200);
  }

  @override
  void close() {}
}
// FakeGoogleSignIn is defined below in the Auth section

// ignore: must_be_immutable
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
// ignore: must_be_immutable
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
// ignore: must_be_immutable
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

class MockIdTokenResult extends Mock implements IdTokenResult {
  @override
  final Map<String, dynamic>? claims;
  
  MockIdTokenResult({this.claims});
}

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  
  FakeUser({required this.uid, this.email, this.displayName});

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'mock_token';

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    return MockIdTokenResult(claims: {});
  }
}

class FakeAuthService extends Fake implements AuthService {
  User? _currentUser;
  Map<String, dynamic>? mockClaims;
  bool signOutCalled = false;

  FakeAuthService({User? user}) : _currentUser = user;

  @override
  User? get currentUser => _currentUser;
  
  set currentUser(User? user) => _currentUser = user;

  @override
  Future<IdTokenResult?> getIdTokenResult({bool forceRefresh = false}) async {
    return MockIdTokenResult(claims: mockClaims);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _currentUser = null;
  }
}

class FakeDeviceSessionService extends Fake implements DeviceSessionService {
  String deviceId = 'test_device_id';
  
  @override
  Future<String> getOrCreateDeviceId() async => deviceId;

  @override
  Future<void> registerDevice(String userId) async {}

  @override
  Future<void> heartbeatSync(String userId, {String? currentDeviceName}) async {}
}

class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool canCheck = true;
  bool isSupported = true;
  List<BiometricType> availableBiometrics = [BiometricType.fingerprint];
  bool authResult = true;
  String? lastReason;
  AuthenticationOptions? lastOptions;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => availableBiometrics;

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const <dynamic>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    lastReason = localizedReason;
    lastOptions = options;
    return authResult;
  }
}

class FakeDocumentPlatformActions extends Fake implements DocumentPlatformActions {
  Uri? lastLaunchedUrl;
  LaunchMode? lastLaunchMode;
  bool canLaunch = true;
  bool launchResult = true;
  List<XFile>? lastSharedFiles;
  bool layoutPdfCalled = false;

  @override
  Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
    lastLaunchedUrl = url;
    lastLaunchMode = mode;
    return launchResult;
  }

  @override
  Future<bool> canLaunchUrl(Uri url) async => canLaunch;

  @override
  Future<void> layoutPdf({required Future<Uint8List> Function(PdfPageFormat) onLayout}) async {
    layoutPdfCalled = true;
    // We don't necessarily need to call onLayout unless we want to test pdf generation content
  }

  @override
  Future<void> shareXFiles(List<XFile> files, {String? subject}) async {
    lastSharedFiles = files;
  }
}

class FakeObjectBoxProvider extends Fake implements ObjectBoxProvider {
  final FakeStore fakeStore;

  FakeObjectBoxProvider([FakeStore? store]) : fakeStore = store ?? FakeStore();
  
  @override
  Store get store => fakeStore;

  @override
  Box<SyncQueueItem> get syncQueueBox => fakeStore.box<SyncQueueItem>();
  @override
  Box<Transaction> get transactionBox => fakeStore.box<Transaction>();
  @override
  Box<Pelanggan> get pelangganBox => fakeStore.box<Pelanggan>();
  @override
  Box<Stok> get stokBox => fakeStore.box<Stok>();
  @override
  Box<Staff> get staffBox => fakeStore.box<Staff>();
  @override
  Box<Vehicle> get vehicleBox => fakeStore.box<Vehicle>();
  @override
  Box<StokHistory> get stokHistoryBox => fakeStore.box<StokHistory>();
  @override
  Box<Sale> get saleBox => fakeStore.box<Sale>();
  @override
  Box<Expense> get expenseBox => fakeStore.box<Expense>();
  @override
  Box<DebtPayment> get debtPaymentBox => fakeStore.box<DebtPayment>();
  
  // ServiceMaster is often accessed via Box<ServiceMaster>(db.store)
  @override
  Box<ServiceMaster> get serviceMasterBox => fakeStore.box<ServiceMaster>();
}

class FakeStore extends Fake implements Store {
  final Map<Type, FakeBox> _boxes = {};

  @override
  Box<T> box<T>() {
    return (_boxes[T] ??= FakeBox<T>()) as Box<T>;
  }

  @override
  R runInTransaction<R>(TxMode mode, R Function() fn) => fn();

  @override
  Future<R> runInTransactionAsync<R, P>(TxMode mode, R Function(Store store, P parameter) fn, P parameter) async => 
      fn(this, parameter);

  @override
  bool isClosed() => false;

  @override
  void close() {}
}

class FakeBox<T> extends Fake implements Box<T> {
  final Map<int, T> _data = {};
  int _nextId = 1;

  /// Hook to provide custom filtering logic in tests
  bool Function(T item, Condition<T>? condition)? queryPredicate;

  /// Hook to intercept query creation
  void Function(FakeQuery<T> query)? onQueryCreated;

  @override
  int put(T entity, {PutMode mode = PutMode.put}) {
    // Attempt to set 'id' using reflection-like check for common entities
    try {
      // ignore: avoid_dynamic_calls
      if ((entity as dynamic).id == 0) {
        // ignore: avoid_dynamic_calls
        (entity as dynamic).id = _nextId++;
      }
      // ignore: avoid_dynamic_calls
      _data[(entity as dynamic).id] = entity;
      // ignore: avoid_dynamic_calls
      return (entity as dynamic).id;
    } catch (_) {
      // Fallback for types without 'id' field
      _data[_nextId] = entity;
      return _nextId++;
    }
  }

  @override
  List<int> putMany(List<T> entities, {PutMode mode = PutMode.put}) {
    return entities.map((e) => put(e)).toList();
  }

  @override
  T? get(int id) => _data[id];

  @override
  List<T> getAll() => _data.values.toList();

  List<T> get items => getAll();

  @override
  bool remove(int id) => _data.remove(id) != null;

  @override
  int removeMany(List<int> ids) {
    int count = 0;
    for (final id in ids) {
      if (remove(id)) count++;
    }
    return count;
  }

  @override
  int removeAll() {
    final count = _data.length;
    _data.clear();
    return count;
  }

  @override
  int count({int limit = 0}) => _data.length;

  @override
  bool isEmpty() => _data.isEmpty;

  // For Querying support
  @override
  QueryBuilder<T> query([Condition<T>? qc]) => FakeQueryBuilder<T>(this, qc);
}

class FakeQueryBuilder<T> extends Fake implements QueryBuilder<T> {
  final FakeBox<T> _box;
  final Condition<T>? _condition;

  FakeQueryBuilder(this._box, [this._condition]);

  @override
  QueryBuilder<T> order<D>(QueryProperty<T, D> p, {int flags = 0}) => this;

  @override
  Query<T> build() {
    final q = FakeQuery<T>(_box, _condition);
    _box.onQueryCreated?.call(q);
    return q;
  }
}

class FakeQuery<T> extends Fake implements Query<T> {
  final FakeBox<T> _box;
  final Condition<T>? _condition;
  @override
  int limit = 0;
  @override
  int offset = 0;
  List<T>? mockResults;

  FakeQuery(this._box, [this._condition]);

  @override
  T? findFirst() {
    final all = find();
    return all.isEmpty ? null : all.first;
  }

  @override
  List<T> find() {
    if (mockResults != null) return mockResults!;
    var results = _box.getAll();
    if (_box.queryPredicate != null) {
      results = results.where((item) => _box.queryPredicate!(item, _condition)).toList();
    }

    if (offset > 0) {
      if (offset >= results.length) return [];
      results = results.sublist(offset);
    }
    if (limit > 0) {
      results = results.take(limit).toList();
    }

    return results;
  }
  
  @override
  int count() => (mockResults ?? _box.getAll()).length;

  @override
  void close() {}
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? mockUser;
  bool signInCalled = false;
  bool silentSignInCalled = false;
  bool signOutCalled = false;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    signInCalled = true;
    return mockUser;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) async {
    silentSignInCalled = true;
    return mockUser;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalled = true;
    mockUser = null;
    return null;
  }
}

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  final String email;
  @override
  final String id;
  @override
  final String? displayName;
  @override
  final String? photoUrl;

  FakeGoogleSignInAccount({
    required this.email,
    required this.id,
    this.displayName,
    this.photoUrl,
  });

  @override
  Future<GoogleSignInAuthentication> get authentication async => FakeGoogleSignInAuthentication();
}

class FakeGoogleSignInAuthentication extends Fake implements GoogleSignInAuthentication {
  @override
  String get accessToken => 'mock_access_token';
  @override
  String get idToken => 'mock_id_token';
}

class FakeEncryptionService extends Fake implements EncryptionService {
  @override
  String encryptText(String plainText) => 'enc:$plainText';

  @override
  DecryptionResult decryptText(String encryptedText) {
    if (encryptedText.startsWith('enc:')) {
      return DecryptionResult.success(encryptedText.substring(4));
    }
    return DecryptionResult.unencrypted(encryptedText);
  }

  @override
  String hashPin(String pin, String bengkelId) => 'hash:$pin:$bengkelId';

  @override
  Future<String?> wrapMasterKey(String pin, String bengkelId) async {
    return 'enc:wrapped:$pin:$bengkelId';
  }

  @override
  Future<bool> unwrapAndSaveMasterKey(
    String wrappedKey, 
    String pin, 
    String bengkelId, {
    Future<void> Function(String newWrappedKey)? onMigrationComplete,
  }) async {
    return wrappedKey == 'wrapped:$pin:$bengkelId';
  }

  @override
  Future<encrypt.Key> deriveKey(String pin, String salt) async {
    return encrypt.Key.fromUtf8('derived:$pin:$salt'.padRight(32).substring(0, 32));
  }

  @override
  String encryptTextWithKey(String text, encrypt.Key key) {
    return 'enc:v1:keyenc:$text';
  }

  @override
  String decryptTextWithKey(String encryptedText, encrypt.Key key) {
    if (encryptedText.startsWith('enc:v1:keyenc:')) {
      return encryptedText.substring(14);
    }
    if (encryptedText.startsWith('enc:v1:')) {
      // Mock successful decryption for any other enc:v1: data
      return encryptedText.substring(7);
    }
    return '[Gagal Dekripsi]';
  }

  @override
  bool get isInitialized => true;

  @override
  void lock() {}
}
class FakeFirestoreSyncService extends Fake implements FirestoreSyncService {
  final List<Map<String, dynamic>> pushedItems = [];
  bool shouldFail = false;

  @override
  Future<void> pushTransaction(String bengkelId, Transaction tx) async {
    if (shouldFail) throw Exception('Sync failed');
    pushedItems.add({
      'type': 'transaction',
      'bengkelId': bengkelId,
      'entityUuid': tx.uuid,
    });
  }

  @override
  Future<void> pushPelanggan(String bengkelId, Pelanggan p) async {
    if (shouldFail) throw Exception('Sync failed');
    pushedItems.add({
      'type': 'pelanggan',
      'bengkelId': bengkelId,
      'entityUuid': p.uuid,
    });
  }

  @override
  Future<void> pushStok(String bengkelId, Stok s) async {
    if (shouldFail) throw Exception('Sync failed');
    pushedItems.add({
      'type': 'stok',
      'bengkelId': bengkelId,
      'entityUuid': s.uuid,
    });
  }

  @override
  Future<void> pushStaff(String bengkelId, Staff s) async {
    if (shouldFail) throw Exception('Sync failed');
    pushedItems.add({
      'type': 'staff',
      'bengkelId': bengkelId,
      'entityUuid': s.uuid,
    });
  }

  @override
  Future<void> pushVehicle(String bengkelId, Vehicle v) async {
    if (shouldFail) throw Exception('Sync failed');
    pushedItems.add({
      'type': 'vehicle',
      'bengkelId': bengkelId,
      'entityUuid': v.uuid,
    });
  }

  @override
  Future<void> pushStokHistory(String bengkelId, StokHistory sh) async {
    if (shouldFail) throw Exception('Sync failed');
    pushedItems.add({
      'type': 'stok_history',
      'bengkelId': bengkelId,
      'entityUuid': sh.uuid,
    });
  }
}

class FakeSessionManager extends Fake implements SessionManager {
  SessionStatus mockStatus = SessionStatus.valid;

  @override
  Future<SessionStatus> validateSession() async => mockStatus;
}

class FakeSyncWorker extends Fake implements SyncWorker {
  bool syncCalled = false;
  final List<Map<String, dynamic>> enqueuedItems = [];

  @override
  void enqueue({
    required String entityType,
    required String entityUuid,
    SyncPriority priority = SyncPriority.normal,
  }) {
    enqueuedItems.add({
      'entityType': entityType,
      'entityUuid': entityUuid,
      'priority': priority,
    });
  }

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void dispose() {}
}

class FakeSyncLockManager extends Fake implements SyncLockManager {
  bool _isLocked = false;
  
  @override
  Future<bool> acquire() async {
    if (_isLocked) return false;
    _isLocked = true;
    return true;
  }

  @override
  Future<void> release() async {
    _isLocked = false;
  }

  @override
  void startAutoHeartbeat() {}

  @override
  void stopAutoHeartbeat() {}
}
class FakeDocumentActions extends Fake implements DocumentPlatformActions {
  Uri? lastLaunchedUrl;
  bool canLaunch = true;
  bool layoutCalled = false;
  List<XFile>? sharedFiles;

  @override
  Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
    lastLaunchedUrl = url;
    return true;
  }

  @override
  Future<bool> canLaunchUrl(Uri url) async => canLaunch;

  @override
  Future<void> layoutPdf({required Future<Uint8List> Function(PdfPageFormat) onLayout}) async {
    layoutCalled = true;
    await onLayout(PdfPageFormat.a4);
  }

  @override
  Future<void> shareXFiles(List<XFile> files, {String? subject}) async {
    sharedFiles = files;
  }
}
