import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// SEC-FIX: Centralized Logger - Production-ready logging dengan level control
/// Replaces debugPrint untuk logging yang lebih baik di production
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  late Logger _logger;
  bool _initialized = false;

  /// Initialize logger dengan level berdasarkan environment
  void init({bool isDebug = false}) {
    if (_initialized) return;

    final logLevel = isDebug ? Level.debug : Level.warning;

    _logger = Logger(
      level: logLevel,
      printer: PrettyPrinter(
        methodCount: isDebug ? 2 : 0,      // Full stack trace di debug
        errorMethodCount: 8,                // Always show error stack
        lineLength: 120,
        colors: isDebug,                    // Colors only in debug
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      output: MultiOutput([
        ConsoleOutput(),
        // SEC-FIX: Custom output untuk crash reporting (sentry, crashlytics)
        _CrashlyticsOutput(),
      ]),
    );

    _initialized = true;
    info('AppLogger initialized', context: 'level=${isDebug ? 'debug' : 'warning'}');
  }

  Logger get logger {
    if (!_initialized) {
      // Auto-initialize dengan safe defaults
      init(isDebug: kDebugMode);
    }
    return _logger;
  }

  /// Log debug message (development only)
  void debug(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    final tag = context != null ? '[$context] ' : '';
    logger.d('$tag$message', error: error, stackTrace: stackTrace);
  }

  /// Log info message
  void info(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    final tag = context != null ? '[$context] ' : '';
    logger.i('$tag$message', error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  void warning(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    final tag = context != null ? '[$context] ' : '';
    logger.w('$tag$message', error: error, stackTrace: stackTrace);
  }

  /// Log error message
  void error(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    final tag = context != null ? '[$context] ' : '';
    logger.e('$tag$message', error: error, stackTrace: stackTrace);

    // Also log to developer console untuk visibility
    if (!kReleaseMode) {
      developer.log(
        '$tag$message',
        name: 'ERROR',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log wtf/critical message
  void critical(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    final tag = context != null ? '[$context] ' : '';
    logger.f('$tag$message', error: error, stackTrace: stackTrace);
  }

  /// Production-safe log - untuk log yang perlu muncul di release juga
  /// Tapi dengan data yang sudah disanitasi (no PII)
  void audit(String action, {String? context, Map<String, dynamic>? metadata}) {
    final sanitizedMetadata = _sanitizeMetadata(metadata ?? {});
    final tag = context != null ? '[$context] ' : '';
    logger.i('[AUDIT] $tag$action', error: sanitizedMetadata);
  }

  /// Sanitize metadata untuk menghindari PII leak di production logs
  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
    final sensitiveKeys = ['password', 'pin', 'token', 'secret', 'key', 'email', 'phone'];
    final sanitized = <String, dynamic>{};

    for (final entry in metadata.entries) {
      final key = entry.key.toLowerCase();
      if (sensitiveKeys.any((s) => key.contains(s))) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }
}

/// Custom output untuk integrasi dengan crash reporting
class _CrashlyticsOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // TODO: Integrate dengan Firebase Crashlytics untuk error logs
    // Saat ini hanya output ke console
    for (final line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

/// Global logger instance untuk kemudahan penggunaan
final appLogger = AppLogger();

/// Extension untuk kemudahan logging di service classes
extension LoggerExtension on Object {
  /// Get logger dengan context dari class name
  void logDebug(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    appLogger.debug(message, context: context ?? runtimeType.toString(), error: error, stackTrace: stackTrace);
  }

  void logInfo(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    appLogger.info(message, context: context ?? runtimeType.toString(), error: error, stackTrace: stackTrace);
  }

  void logWarning(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    appLogger.warning(message, context: context ?? runtimeType.toString(), error: error, stackTrace: stackTrace);
  }

  void logError(String message, {String? context, dynamic error, StackTrace? stackTrace}) {
    appLogger.error(message, context: context ?? runtimeType.toString(), error: error, stackTrace: stackTrace);
  }
}
