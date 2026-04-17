// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$saleRepositoryHash() => r'4967aa3de3f2230c0b6f771c4520c92f92ab7dbd';

/// See also [saleRepository].
@ProviderFor(saleRepository)
final saleRepositoryProvider = AutoDisposeProvider<SaleRepository>.internal(
  saleRepository,
  name: r'saleRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$saleRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SaleRepositoryRef = AutoDisposeProviderRef<SaleRepository>;
String _$customerSalesHash() => r'ab18a47b81f26b1072cdbaf2da78c29f3c4c33e0';

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

/// See also [customerSales].
@ProviderFor(customerSales)
const customerSalesProvider = CustomerSalesFamily();

/// See also [customerSales].
class CustomerSalesFamily extends Family<List<Sale>> {
  /// See also [customerSales].
  const CustomerSalesFamily();

  /// See also [customerSales].
  CustomerSalesProvider call(
    String customerName,
  ) {
    return CustomerSalesProvider(
      customerName,
    );
  }

  @override
  CustomerSalesProvider getProviderOverride(
    covariant CustomerSalesProvider provider,
  ) {
    return call(
      provider.customerName,
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
  String? get name => r'customerSalesProvider';
}

/// See also [customerSales].
class CustomerSalesProvider extends AutoDisposeProvider<List<Sale>> {
  /// See also [customerSales].
  CustomerSalesProvider(
    String customerName,
  ) : this._internal(
          (ref) => customerSales(
            ref as CustomerSalesRef,
            customerName,
          ),
          from: customerSalesProvider,
          name: r'customerSalesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$customerSalesHash,
          dependencies: CustomerSalesFamily._dependencies,
          allTransitiveDependencies:
              CustomerSalesFamily._allTransitiveDependencies,
          customerName: customerName,
        );

  CustomerSalesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.customerName,
  }) : super.internal();

  final String customerName;

  @override
  Override overrideWith(
    List<Sale> Function(CustomerSalesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomerSalesProvider._internal(
        (ref) => create(ref as CustomerSalesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        customerName: customerName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<Sale>> createElement() {
    return _CustomerSalesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerSalesProvider && other.customerName == customerName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, customerName.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CustomerSalesRef on AutoDisposeProviderRef<List<Sale>> {
  /// The parameter `customerName` of this provider.
  String get customerName;
}

class _CustomerSalesProviderElement
    extends AutoDisposeProviderElement<List<Sale>> with CustomerSalesRef {
  _CustomerSalesProviderElement(super.provider);

  @override
  String get customerName => (origin as CustomerSalesProvider).customerName;
}

String _$saleListHash() => r'296d1acecbca42a106c8bba1048970e55d148b34';

/// See also [SaleList].
@ProviderFor(SaleList)
final saleListProvider =
    AutoDisposeAsyncNotifierProvider<SaleList, List<Sale>>.internal(
  SaleList.new,
  name: r'saleListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$saleListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SaleList = AutoDisposeAsyncNotifier<List<Sale>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
