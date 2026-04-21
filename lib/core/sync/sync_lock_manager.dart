import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_logger.dart';

/// 🛡️ SyncLockManager — Stale lock recovery + heartbeat pattern + Instance Validation
/// Prevents concurrent sync operations from multiple app instances or workers.
class SyncLockManager {
  static const _lockFileName = 'servisio_sync.lock';
  static const _heartbeatInterval = Duration(seconds: 10);
  static const _maxLockAge = Duration(minutes: 5);
  static const _validLockThreshold = Duration(seconds: 60);

  // Unique ID for this App instance to prevent cross-releasing
  final String _instanceId = const Uuid().v4();
  
  File? _lockFile;
  Timer? _heartbeatTimer;

  Future<File> get _lockFileInstance async {
    _lockFile ??= File('${(await getTemporaryDirectory()).path}/$_lockFileName');
    return _lockFile!;
  }

  /// Acquire lock with automatic stale detection.
  /// Returns true if lock was acquired, false otherwise.
  Future<bool> acquire() async {
    final file = await _lockFileInstance;
    final lock = await _readLock();

    if (lock != null) {
      // If we already own the lock, just update heartbeat and proceed
      if (lock.instanceId == _instanceId) {
        await _writeLock();
        return true;
      }

      final age = DateTime.now().difference(lock.timestamp);

      // Case 1: Active lock from ANOTHER instance with recent heartbeat → skip
      if (age < _validLockThreshold) {
        appLogger.info('Active lock detected (age: ${age.inSeconds}s, instance: ${lock.instanceId.substring(0, 8)})', context: 'SyncLockManager');
        return false;
      }

      // Case 2: Stale lock > 5 minutes → force break
      if (age > _maxLockAge) {
        appLogger.warning('Breaking stale lock (age: ${age.inMinutes}m, instance: ${lock.instanceId.substring(0, 8)})', context: 'SyncLockManager');
        await file.delete();
      } else {
        // Case 3: Lock exists but no recent heartbeat → wait for recovery window and retry
        appLogger.info('Lock stale detected from instance ${lock.instanceId.substring(0, 8)}, waiting for recovery...', context: 'SyncLockManager');
        await Future.delayed(_heartbeatInterval);
        return acquire(); // Recursive retry
      }
    }

    // Write new lock with current timestamp and instanceId
    await _writeLock();
    return true;
  }

  /// Periodic heartbeat to signal the lock is still alive during long operations.
  Future<void> heartbeat() async {
    final lock = await _readLock();
    // Only update if we still own it
    if (lock != null && lock.instanceId == _instanceId) {
      await _writeLock();
    }
  }

  /// Start auto-heartbeat timer.
  void startAutoHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => heartbeat());
  }

  /// Stop auto-heartbeat timer.
  void stopAutoHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Release the lock safely (only if owned by this instance).
  Future<void> release() async {
    stopAutoHeartbeat();
    final file = await _lockFileInstance;
    final lock = await _readLock();
    
    if (lock != null && lock.instanceId == _instanceId) {
      if (await file.exists()) {
        await file.delete();
        appLogger.info('Lock released by owner ($_instanceId)', context: 'SyncLockManager');
      }
    } else {
      appLogger.info('Release ignored (not the lock owner)', context: 'SyncLockManager');
    }
  }

  Future<_LockData?> _readLock() async {
    try {
      final file = await _lockFileInstance;
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return _LockData.fromJson(jsonDecode(content));
    } catch (e) {
      appLogger.warning('Error reading lock file', context: 'SyncLockManager', error: e);
      return null;
    }
  }

  Future<void> _writeLock() async {
    final file = await _lockFileInstance;
    final data = _LockData(
      timestamp: DateTime.now(),
      pid: _getPid(), // Using real process ID if available (dart:io)
      instanceId: _instanceId,
    );
    await file.writeAsString(jsonEncode(data.toJson()));
  }

  int _getPid() {
    // dart:io is not available on web
    try {
      // ignore: undefined_prefixed_name
      return pid;
    } catch (e) {
      return 0; // Web fallback
    }
  }
}

class _LockData {
  final DateTime timestamp;
  final int pid;
  final String instanceId;

  _LockData({
    required this.timestamp, 
    required this.pid,
    required this.instanceId,
  });

  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'pid': pid,
    'instance_id': instanceId,
  };

  factory _LockData.fromJson(Map<String, dynamic> json) => _LockData(
    timestamp: DateTime.parse(json['ts']),
    pid: json['pid'],
    instanceId: json['instance_id'] ?? 'legacy',
  );
}
