import 'package:mockito/mockito.dart';
import 'package:servislog_core/core/services/biometric_service.dart';

// Note: In a real project, we would mock the actual dependencies of these services.
// Since these are "Dry Run" mocks, we simulate the hardware behavior.

/// Mock Biometric Service for Dry Run testing
class MockBiometricService extends Mock implements BiometricService {
  bool _isAvailable = true;
  bool _shouldSucceed = true;

  void setAvailable(bool value) => _isAvailable = value;
  void setShouldSucceed(bool value) => _shouldSucceed = value;

  @override
  Future<bool> canCheckBiometrics() async => _isAvailable;

  @override
  Future<bool> authenticate({String reason = 'Verifikasi identitas Anda'}) async {
    if (!_isAvailable) return false;
    return _shouldSucceed;
  }
}

/// Generic Mock Printer Service
class MockPrinterService extends Mock {
  List<String> printLogs = [];

  Future<bool> connect(String address) async => true;
  Future<void> printText(String text) async {
    printLogs.add(text);
  }
}
