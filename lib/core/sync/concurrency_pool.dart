import 'dart:async';

/// 🏎️ Pool — Simple concurrency control for parallel operations.
/// Prevents overloading APIs or causing rate limits while maintaining high performance.
class Pool {
  final int _maxConcurrent;
  int _running = 0;
  final _queue = <Completer<void>>[];

  Pool(this._maxConcurrent);

  /// Executes a callback when a resource slot is available.
  Future<T> withResource<T>(Future<T> Function() callback) async {
    // Wait if already at max capacity
    while (_running >= _maxConcurrent) {
      final waiter = Completer<void>();
      _queue.add(waiter);
      await waiter.future;
    }

    _running++;

    try {
      return await callback();
    } finally {
      _running--;
      // Signal the next waiter in the queue
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        next.complete();
      }
    }
  }

  int get available => _maxConcurrent - _running;
  int get running => _running;
  int get queued => _queue.length;
}

