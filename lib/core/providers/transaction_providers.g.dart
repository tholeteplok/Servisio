// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transactionRepositoryHash() =>
    r'5a453900d5b590f553df940c74ac003cae771379';

/// See also [transactionRepository].
@ProviderFor(transactionRepository)
final transactionRepositoryProvider =
    AutoDisposeProvider<TransactionRepository>.internal(
  transactionRepository,
  name: r'transactionRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transactionRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TransactionRepositoryRef
    = AutoDisposeProviderRef<TransactionRepository>;
String _$customerTransactionsHash() =>
    r'33c8879367b38aca2e97044438b0685975917393';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [customerTransactions].
@ProviderFor(customerTransactions)
const customerTransactionsProvider = CustomerTransactionsFamily();

/// See also [customerTransactions].
class CustomerTransactionsFamily extends Family<List<Transaction>> {
  /// See also [customerTransactions].
  const CustomerTransactionsFamily();

  /// See also [customerTransactions].
  CustomerTransactionsProvider call(
    int pelangganId,
  ) {
    return CustomerTransactionsProvider(
      pelangganId,
    );
  }

  @override
  CustomerTransactionsProvider getProviderOverride(
    covariant CustomerTransactionsProvider provider,
  ) {
    return call(
      provider.pelangganId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'customerTransactionsProvider';
}

/// See also [customerTransactions].
class CustomerTransactionsProvider
    extends AutoDisposeProvider<List<Transaction>> {
  /// See also [customerTransactions].
  CustomerTransactionsProvider(
    int pelangganId,
  ) : this._internal(
          (ref) => customerTransactions(
            ref as CustomerTransactionsRef,
            pelangganId,
          ),
          from: customerTransactionsProvider,
          name: r'customerTransactionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$customerTransactionsHash,
          dependencies: CustomerTransactionsFamily._dependencies,
          allTransitiveDependencies:
              CustomerTransactionsFamily._allTransitiveDependencies,
          pelangganId: pelangganId,
        );

  CustomerTransactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.pelangganId,
  }) : super.internal();

  final int pelangganId;

  @override
  Override overrideWith(
    List<Transaction> Function(CustomerTransactionsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomerTransactionsProvider._internal(
        (ref) => create(ref as CustomerTransactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        pelangganId: pelangganId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<Transaction>> createElement() {
    return _CustomerTransactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerTransactionsProvider &&
        other.pelangganId == pelangganId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, pelangganId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CustomerTransactionsRef on AutoDisposeProviderRef<List<Transaction>> {
  /// The parameter `pelangganId` of this provider.
  int get pelangganId;
}

class _CustomerTransactionsProviderElement
    extends AutoDisposeProviderElement<List<Transaction>>
    with CustomerTransactionsRef {
  _CustomerTransactionsProviderElement(super.provider);

  @override
  int get pelangganId => (origin as CustomerTransactionsProvider).pelangganId;
}

String _$transactionListHash() => r'3e3ce9b64e5fccd23d4d068ed44365b005c8897f';

/// See also [TransactionList].
@ProviderFor(TransactionList)
final transactionListProvider = AutoDisposeAsyncNotifierProvider<
    TransactionList, List<Transaction>>.internal(
  TransactionList.new,
  name: r'transactionListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transactionListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransactionList = AutoDisposeAsyncNotifier<List<Transaction>>;
String _$paginatedTransactionListHash() =>
    r'456c2b4e1c2f5237fb349a7f0a5a42ab05b68ec9';

/// See also [PaginatedTransactionList].
@ProviderFor(PaginatedTransactionList)
final paginatedTransactionListProvider = AutoDisposeNotifierProvider<
    PaginatedTransactionList, PaginatedTransactionState>.internal(
  PaginatedTransactionList.new,
  name: r'paginatedTransactionListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paginatedTransactionListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PaginatedTransactionList
    = AutoDisposeNotifier<PaginatedTransactionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
