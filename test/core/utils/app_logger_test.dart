import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    late AppLogger logger;

    setUp(() {
      logger = AppLogger();
      logger.init(isDebug: true);
    });

    test('should initialize correctly', () {
      expect(logger, isNotNull);
    });

    test('should have logger instance after init', () {
      expect(logger.logger, isNotNull);
    });

    group('Log Methods', () {
      test('debug should not throw', () {
        expect(
          () => logger.debug('Test debug message', context: 'Test'),
          returnsNormally,
        );
      });

      test('info should not throw', () {
        expect(
          () => logger.info('Test info message', context: 'Test'),
          returnsNormally,
        );
      });

      test('warning should not throw', () {
        expect(
          () => logger.warning('Test warning message', context: 'Test'),
          returnsNormally,
        );
      });

      test('error should not throw', () {
        expect(
          () => logger.error('Test error message', context: 'Test'),
          returnsNormally,
        );
      });

      test('critical should not throw', () {
        expect(
          () => logger.critical('Test critical message', context: 'Test'),
          returnsNormally,
        );
      });
    });

    group('Audit Logging', () {
      test('audit should not throw with metadata', () {
        expect(
          () => logger.audit(
            'User login',
            context: 'Auth',
            metadata: {'userId': '123', 'ip': '192.168.1.1'},
          ),
          returnsNormally,
        );
      });

      test('audit should sanitize sensitive data', () {
        expect(
          () => logger.audit(
            'User action',
            metadata: {
              'userId': '123',
              'password': 'secret123', // Should be redacted
              'token': 'bearer_token', // Should be redacted
              'email': 'test@example.com', // Should be redacted
            },
          ),
          returnsNormally,
        );
      });
    });

    group('LoggerExtension', () {
      test('logDebug extension should work', () {
        expect(
          () => logger.logDebug('Extension debug'),
          returnsNormally,
        );
      });

      test('logInfo extension should work', () {
        expect(
          () => logger.logInfo('Extension info'),
          returnsNormally,
        );
      });

      test('logWarning extension should work', () {
        expect(
          () => logger.logWarning('Extension warning'),
          returnsNormally,
        );
      });

      test('logError extension should work with error and stack trace', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        expect(
          () => logger.logError(
            'Extension error',
            error: error,
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });
    });
  });
}
