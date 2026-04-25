import 'sync_telemetry.dart';
import '../utils/app_logger.dart';

/// 🛡️ HierarchicalCircuitBreaker — Global + per-item error isolation.
/// Prevents repetitive failures from overloading the system or causing lag.
enum SyncDecision { proceed, block, skip }

enum DriveErrorType {
  quotaExceeded,
  rateLimit,
  auth,
  permission,
  notFound,
  server,
  network,
  unknown,
}

class HierarchicalCircuitBreaker {
  // Level 1: Global (untuk quota/auth errors)
  static final _global = _CircuitBreaker(
    name: 'global',
    failureThreshold: 3,
    resetTimeout: const Duration(minutes: 15),
  );

  // Level 2: Per-item tracking
  final Map<String, _CircuitBreaker> _itemBreakers = {};

  /// Evaluate if item should proceed based on its error type and current state.
  SyncDecision shouldProceed(String itemId, DriveErrorType error) {
    // Global always checked first
    if (_global.isOpen) {
      appLogger.warning('Global circuit open: ${_global.state}', context: 'CircuitBreaker');
      return SyncDecision.block;
    }

    // Per-item breaker for non-global errors
    if (_isItemLevelError(error)) {
      final breaker = _itemBreakers.putIfAbsent(
        itemId,
        () => _CircuitBreaker(name: 'item_$itemId', failureThreshold: 2),
      );

      if (breaker.isOpen) {
        appLogger.info('Item-level breaker open for $itemId: ${breaker.state}', context: 'CircuitBreaker');
        return SyncDecision.skip;
      }
    }

    return SyncDecision.proceed;
  }

  void recordSuccess(String itemId) {
    _itemBreakers[itemId]?.recordSuccess();
  }

  void recordFailure(String itemId, DriveErrorType error) {
    if (_isGlobalError(error)) {
      _global.recordFailure();
      appLogger.warning('Global circuit failure recorded: ${error.name}', context: 'CircuitBreaker');
    } else {
      _itemBreakers.putIfAbsent(
        itemId,
        () => _CircuitBreaker(name: 'item_$itemId', failureThreshold: 2),
      ).recordFailure();
      appLogger.info('Item-level failure recorded: $itemId - ${error.name}', context: 'CircuitBreaker');
    }
  }

  bool _isGlobalError(DriveErrorType error) =>
    error == DriveErrorType.quotaExceeded ||
    error == DriveErrorType.rateLimit ||
    error == DriveErrorType.auth;

  bool _isItemLevelError(DriveErrorType error) =>
    error == DriveErrorType.notFound ||
    error == DriveErrorType.permission ||
    error == DriveErrorType.server ||
    error == DriveErrorType.network;

  /// Reset all breakers (for manual recovery or status change).
  void resetAll() {
    _global.reset();
    _itemBreakers.clear();
    appLogger.info('All circuit breakers reset', context: 'CircuitBreaker');
  }

  /// Get status for debugging purposes.
  Map<String, dynamic> get status => {
    'global': _global.state,
    'itemBreakerCount': _itemBreakers.length,
  };
}

class _CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration resetTimeout;

  int _failureCount = 0;
  DateTime? _lastFailureTime;

  _CircuitBreaker({
    required this.name,
    required this.failureThreshold,
    this.resetTimeout = const Duration(minutes: 5),
  });

  bool get isOpen {
    if (_failureCount >= failureThreshold) {
      if (_lastFailureTime != null) {
        final elapsed = DateTime.now().difference(_lastFailureTime!);
        if (elapsed > resetTimeout) {
          reset();
          return false;
        }
      }
      return true;
    }
    return false;
  }

  String get state => isOpen ? 'OPEN' : 'CLOSED';

  void recordSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
  }

  void reset() {
    final wasOpen = isOpen;
    _failureCount = 0;
    _lastFailureTime = null;
    
    if (wasOpen) {
      SyncTelemetry().log(SyncEvent(
        type: 'circuit_breaker_reset',
        metadata: {'name': name},
        level: TelemetryLevel.info,
        timestamp: DateTime.now(),
      ));
    }
    
    appLogger.info('Circuit breaker $name reset', context: 'CircuitBreaker');
  }
}

