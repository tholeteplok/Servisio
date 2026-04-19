import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:servislog_core/core/services/backup_service.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late FakeStore fakeStore;
  late FakeObjectBoxProvider fakeDb;
  late BackupService service;

  setUp(() {
    fakeStore = FakeStore();
    fakeDb = FakeObjectBoxProvider(fakeStore);
    service = BackupService(fakeDb, FakeEncryptionService());
  });

  group('BackupService Tests', () {
    test('importFromJson() should decrypt sensitive fields if PIN provided', () async {
      final encryption = FakeEncryptionService();
      final backupKey = await encryption.deriveKey('123456', 'b-1');
      final encryptedName = encryption.encryptTextWithKey('Budi', backupKey);
      final encryptedPhone = encryption.encryptTextWithKey('123', backupKey);
      final encryptedAlamat = encryption.encryptTextWithKey('Jalan', backupKey);
      
      final mockData = {
        'metadata': {
          'isEncrypted': true,
          'bengkelId': 'b-1',
        },
        'pelanggan': [
          {
            'uuid': 'p-1',
            'nama': encryptedName,
            'telepon': encryptedPhone,
            'alamat': encryptedAlamat,
          }
        ]
      };
      
      final result = await service.importFromJson(
        jsonEncode(mockData),
        userPin: '123456',
      );
      
      final pelanggan = (result['pelanggan'] as List).first;
      expect(pelanggan['nama'], 'Budi');
      expect(pelanggan['telepon'], '123');
    });

    test('importFromJson() should throw if PIN missing for encrypted backup', () async {
      final mockData = {
        'metadata': {
          'isEncrypted': true,
          'bengkelId': 'b-1',
        },
        'pelanggan': []
      };
      
      expect(
        () => service.importFromJson(jsonEncode(mockData)),
        throwsException,
      );
    });
  });
}
