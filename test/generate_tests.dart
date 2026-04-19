// ignore_for_file: avoid_print
import 'dart:io';


void main() {
  final services = [
    'AuthService',
    'BiometricService',
    'SessionManager',
    'BengkelService',
    'PelangganService',
    'KatalogService',
    'StokService',
    'PemasokService',
    'TransaksiService',
    'ServiceRecordsService',
    'BackupService',
    'FirestoreSyncService',
    'NotificationService',
    'PrinterService',
    'ReportService',
    'SettingService',
    'TechnicianService',
    'VehicleService',
    'PaymentService',
    'AccountingService',
  ];

  final testDir = Directory('test/core/services');
  if (!testDir.existsSync()) {
    testDir.createSync(recursive: true);
  }

  for (final service in services) {
    final fileName = '${_toSnakeCase(service)}_test.dart';
    final filePath = '${testDir.path}/$fileName';
    final file = File(filePath);

    if (file.existsSync()) {
      print('Skipping $fileName - already exists');
      continue;
    }

    final content = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../helpers/test_utils.dart';

@GenerateMocks([])
void main() {
  group('$service Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state should be correct', () {
      // TODO: Implement test logic for $service
    });
  });
}
''';
    file.writeAsStringSync(content);
    print('Generated $fileName');
  }
}

String _toSnakeCase(String text) {
  return text.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)}',
  ).toLowerCase();
}
