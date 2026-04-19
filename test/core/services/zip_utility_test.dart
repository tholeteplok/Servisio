import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servislog_core/core/services/zip_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appDocDir;

  setUp(() async {
    // 1. Setup mock paths
    tempDir = await Directory.systemTemp.createTemp('zip_utility_test_temp');
    appDocDir = await Directory.systemTemp.createTemp('zip_utility_test_appdoc');

    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return tempDir.path;
      }
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return appDocDir.path;
      }
      return null;
    });

    // 2. Setup mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    if (await appDocDir.exists()) await appDocDir.delete(recursive: true);
  });

  group('ZipUtility Tests', () {
    test('createBackupZip should create a valid ZIP with settings and directories', () async {
      // 1. Prepare dummy data
      final settingsJson = jsonEncode({'theme': 'dark', 'notifications': true});
      
      final mediaDir = Directory(p.join(appDocDir.path, 'media'));
      await mediaDir.create();
      await File(p.join(mediaDir.path, 'test_image.jpg')).writeAsString('image_data');

      final objectboxDir = Directory(p.join(appDocDir.path, 'objectbox'));
      await objectboxDir.create();
      await File(p.join(objectboxDir.path, 'data.mdb')).writeAsString('database_data');

      // 2. Run backup
      final zipFile = await ZipUtility.createBackupZip(settingsJson);

      // 3. Verify ZIP exists and is not empty
      expect(await zipFile.exists(), true);
      expect(await zipFile.length() > 0, true);
      
      // Verification of contents happens implicitly in extract test
    });

    test('extractRestoreZip should restore files and settings correctly', () async {
      // 1. Create a backup first
      final settingsJson = jsonEncode({'theme': 'light'});
      
      final objectboxDir = Directory(p.join(appDocDir.path, 'objectbox'));
      await objectboxDir.create();
      await File(p.join(objectboxDir.path, 'data.mdb')).writeAsString('database_data');

      final zipFile = await ZipUtility.createBackupZip(settingsJson);

      // 2. Clear local data to simulate restore environment
      await File(p.join(objectboxDir.path, 'data.mdb')).delete();
      
      // 3. Run restore
      await ZipUtility.extractRestoreZip(zipFile);

      // 4. Verify files restored
      expect(await File(p.join(objectboxDir.path, 'data.mdb')).exists(), true);
      expect(await File(p.join(objectboxDir.path, 'data.mdb')).readAsString(), 'database_data');

      // 5. Verify settings restored to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme'), 'light');
    });

    test('extractRestoreZip should throw if ZIP is corrupt/missing items', () async {
      // Create a ZIP that is missing objectbox/ directory contents
      final settingsJson = jsonEncode({'theme': 'dark'});
      
      // We don't create or fill 'objectbox' dir, so createBackupZip won't include any 'objectbox/...' entries.
      final zipFile = await ZipUtility.createBackupZip(settingsJson);
      
      await expectLater(
        ZipUtility.extractRestoreZip(zipFile),
        throwsA(predicate((e) => e.toString().contains('Missing required directories'))),
      );
    });
  });
}
