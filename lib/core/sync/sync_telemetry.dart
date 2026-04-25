import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'circuit_breaker.dart'; // For error typing
import '../utils/app_logger.dart';

/// 📊 SyncTelemetry — Structured logging for production observability.
/// Dispatches logs to Firebase Crashlytics and local storage.
enum TelemetryLevel { debug, info, warning, error }

class SyncEvent {
  final String type;
  final String? photoId;
  final String? entityUuid;
  final DateTime timestamp;
  final String? sessionId;
  final String? deviceId;
  final Map<String, dynamic> metadata;
  final TelemetryLevel level;
  final StackTrace? stackTrace;

  SyncEvent({
    required this.type,
    this.photoId,
    this.entityUuid,
    required this.timestamp,
    this.sessionId,
    this.deviceId,
    this.metadata = const {},
    this.level = TelemetryLevel.info,
    this.stackTrace,
  });

  SyncEvent copyWith({
    DateTime? timestamp,
    String? sessionId,
    String? deviceId,
  }) => SyncEvent(
    type: type,
    photoId: photoId,
    entityUuid: entityUuid,
    timestamp: timestamp ?? this.timestamp,
    sessionId: sessionId ?? this.sessionId,
    deviceId: deviceId ?? this.deviceId,
    metadata: metadata,
    level: level,
    stackTrace: stackTrace,
  );

  @override
  String toString() =>
    '[${timestamp.toIso8601String()}] $type | entity: ${entityUuid ?? photoId} | $metadata';
}

abstract class TelemetrySink {
  void send(SyncEvent event);
}

class SyncTelemetry {
  static final SyncTelemetry _instance = SyncTelemetry._();
  factory SyncTelemetry() {
    // Auto-initialize with default sinks if never initialized
    if (!_instance._isInitialized) {
      _instance._initializeDefault();
    }
    return _instance;
  }
  SyncTelemetry._();

  bool _isInitialized = false;
  final List<TelemetrySink> _sinks = [];
  String? _sessionId;
  String? _deviceId;

  void _initializeDefault() {
    final sinks = <TelemetrySink>[];
    
    // Add Crashlytics for mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      sinks.add(FirebaseTelemetrySink());
    }
    
    // Always add local file for audit trail
    sinks.add(LocalFileTelemetrySink());
    
    initialize(sinks, deviceId: 'pending');
  }

  void initialize(List<TelemetrySink> sinks, {required String deviceId}) {
    _sinks.clear();
    _sinks.addAll(sinks);
    _sessionId = _generateSessionId();
    _deviceId = deviceId;
    _isInitialized = true;
    appLogger.info('SyncTelemetry initialized with session=$_sessionId', context: 'SyncTelemetry');
  }

  void log(SyncEvent event) {
    final enriched = event.copyWith(
      timestamp: DateTime.now(),
      sessionId: _sessionId,
      deviceId: _deviceId,
    );

    for (var sink in _sinks) {
      sink.send(enriched);
    }

    // Local debug print
    if (kDebugMode) {
      appLogger.debug('[SYNC:${enriched.level.name.toUpperCase()}] ${enriched.toString()}', context: 'SyncTelemetry');
    }
  }

  // Convenience methods
  void syncStart(String entityUuid, String type, {int? fileSize}) => log(SyncEvent(
    type: 'sync_start',
    entityUuid: entityUuid,
    metadata: {
      'entity_type': type,
      // ignore: use_null_aware_elements
      if (fileSize != null) 'size': fileSize,
    },
    level: TelemetryLevel.info,
    timestamp: DateTime.now(),
  ));

  void syncSuccess(String entityUuid, Duration duration) => log(SyncEvent(
    type: 'sync_success',
    entityUuid: entityUuid,
    metadata: {
      'duration_ms': duration.inMilliseconds,
    },
    level: TelemetryLevel.info,
    timestamp: DateTime.now(),
  ));

  void syncFailed(String entityUuid, String error, {DriveErrorType? errorType, int? retryCount}) => log(SyncEvent(
    type: 'sync_failed',
    entityUuid: entityUuid,
    metadata: {
      'error': error,
      // ignore: use_null_aware_elements
      if (errorType != null) 'error_type': errorType.name,
      // ignore: use_null_aware_elements
      if (retryCount != null) 'retry_count': retryCount,
    },
    level: TelemetryLevel.error,
    timestamp: DateTime.now(),
  ));

  void circuitBreakerOpened(String scope) => log(SyncEvent(
    type: 'circuit_breaker_opened',
    metadata: {'scope': scope},
    level: TelemetryLevel.warning,
    timestamp: DateTime.now(),
  ));

  void lockAcquired() => log(SyncEvent(
    type: 'lock_acquired',
    level: TelemetryLevel.debug,
    timestamp: DateTime.now(),
  ));

  void lockReleased() => log(SyncEvent(
    type: 'lock_released',
    level: TelemetryLevel.debug,
    timestamp: DateTime.now(),
  ));

  /// 🛡️ Audit: Record security-sensitive events (Audit K-3)
  void securityEvent(String eventType, {required String userId, Map<String, dynamic>? extra}) => log(SyncEvent(
    type: 'auth_$eventType',
    metadata: {
      'user_id': userId,
      if (extra != null) ...extra,
    },
    level: TelemetryLevel.warning, // Security events are at least warnings
    timestamp: DateTime.now(),
  ));

  String _generateSessionId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond)}';
}

/// Sink to send logs to Firebase Crashlytics.
class FirebaseTelemetrySink implements TelemetrySink {
  @override
  void send(SyncEvent event) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FirebaseCrashlytics.instance.log(event.toString());
      FirebaseCrashlytics.instance.setCustomKey('sync_session', event.sessionId ?? 'unknown');
      FirebaseCrashlytics.instance.setCustomKey('sync_type', event.type);

      if (event.level == TelemetryLevel.error) {
        FirebaseCrashlytics.instance.recordError(
          Exception('${event.type}: ${event.metadata}'),
          event.stackTrace ?? StackTrace.current,
          reason: event.toString(),
          fatal: false,
        );
      }
    }
  }
}

/// Sink to write logs to a local file for emergency lookup.
/// Uses a buffer-like approach to minimize I/O overhead.
class LocalFileTelemetrySink implements TelemetrySink {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxFiles = 5;
  static final List<String> _buffer = [];
  static bool _isWriting = false;

  @override
  void send(SyncEvent event) async {
    _buffer.add('${event.toString()}\n');
    _processBuffer();
  }

  Future<void> _processBuffer() async {
    if (_isWriting || _buffer.isEmpty) return;
    _isWriting = true;

    try {
      final dir = await getApplicationSupportDirectory(); // Better for logs than documents
      final file = File('${dir.path}/security_audit.log');
      
      // Check file size before writing
      if (await file.exists()) {
        final size = await file.length();
        if (size > _maxFileSizeBytes) {
          await _rotateLogs(dir);
        }
      }
      
      final sink = file.openWrite(mode: FileMode.append);
      while (_buffer.isNotEmpty) {
        sink.write(_buffer.removeAt(0));
      }
      await sink.close();
    } catch (_) {
      // Never crash during telemetry
    } finally {
      _isWriting = false;
      if (_buffer.isNotEmpty) _processBuffer();
    }
  }

  Future<void> _rotateLogs(Directory dir) async {
    for (int i = _maxFiles - 1; i > 0; i--) {
      final oldFile = File('${dir.path}/security_audit.log.$i');
      final newFile = File('${dir.path}/security_audit.log.${i + 1}');
      if (await oldFile.exists()) {
        await oldFile.rename(newFile.path);
      }
    }
    
    final mainFile = File('${dir.path}/security_audit.log');
    if (await mainFile.exists()) {
      await mainFile.rename('${dir.path}/security_audit.log.1');
    }
  }
}

