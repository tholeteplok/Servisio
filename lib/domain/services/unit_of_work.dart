import '../../objectbox.g.dart';

/// Abstract interface for Unit of Work pattern to ensure ACID transactions.
abstract class UnitOfWork {
  T execute<T>(T Function() action);
}

/// ObjectBox implementation of Unit of Work.
class ObjectBoxUnitOfWork implements UnitOfWork {
  final Store _store;

  ObjectBoxUnitOfWork(this._store);

  @override
  T execute<T>(T Function() action) {
    return _store.runInTransaction(TxMode.write, action);
  }
}
