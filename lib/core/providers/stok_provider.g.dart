// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stok_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$stokRepositoryHash() => r'b69b4a7e7a2cee888e1f12841e18ca6b922b0c64';

/// See also [stokRepository].
@ProviderFor(stokRepository)
final stokRepositoryProvider = AutoDisposeProvider<StokRepository>.internal(
  stokRepository,
  name: r'stokRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stokRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StokRepositoryRef = AutoDisposeProviderRef<StokRepository>;
String _$stokHistoryRepositoryHash() =>
    r'973791b827a5094f998f345ce6132c3d08d98543';

/// See also [stokHistoryRepository].
@ProviderFor(stokHistoryRepository)
final stokHistoryRepositoryProvider =
    AutoDisposeProvider<StokHistoryRepository>.internal(
  stokHistoryRepository,
  name: r'stokHistoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stokHistoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StokHistoryRepositoryRef
    = AutoDisposeProviderRef<StokHistoryRepository>;
String _$sortedStokHash() => r'a094263c3142e6ae6c274370e3bdfe8fd2ee8937';

/// See also [sortedStok].
@ProviderFor(sortedStok)
final sortedStokProvider = AutoDisposeProvider<List<Stok>>.internal(
  sortedStok,
  name: r'sortedStokProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sortedStokHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SortedStokRef = AutoDisposeProviderRef<List<Stok>>;
String _$stokHistoryHash() => r'a0442e60ff9db590be00bdaac2adac8b8fd5bf46';

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

/// See also [stokHistory].
@ProviderFor(stokHistory)
const stokHistoryProvider = StokHistoryFamily();

/// See also [stokHistory].
class StokHistoryFamily extends Family<List<StokHistory>> {
  /// See also [stokHistory].
  const StokHistoryFamily();

  /// See also [stokHistory].
  StokHistoryProvider call(
    String stokUuid,
  ) {
    return StokHistoryProvider(
      stokUuid,
    );
  }

  @override
  StokHistoryProvider getProviderOverride(
    covariant StokHistoryProvider provider,
  ) {
    return call(
      provider.stokUuid,
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
  String? get name => r'stokHistoryProvider';
}

/// See also [stokHistory].
class StokHistoryProvider extends AutoDisposeProvider<List<StokHistory>> {
  /// See also [stokHistory].
  StokHistoryProvider(
    String stokUuid,
  ) : this._internal(
          (ref) => stokHistory(
            ref as StokHistoryRef,
            stokUuid,
          ),
          from: stokHistoryProvider,
          name: r'stokHistoryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$stokHistoryHash,
          dependencies: StokHistoryFamily._dependencies,
          allTransitiveDependencies:
              StokHistoryFamily._allTransitiveDependencies,
          stokUuid: stokUuid,
        );

  StokHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.stokUuid,
  }) : super.internal();

  final String stokUuid;

  @override
  Override overrideWith(
    List<StokHistory> Function(StokHistoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StokHistoryProvider._internal(
        (ref) => create(ref as StokHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        stokUuid: stokUuid,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<StokHistory>> createElement() {
    return _StokHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StokHistoryProvider && other.stokUuid == stokUuid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, stokUuid.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin StokHistoryRef on AutoDisposeProviderRef<List<StokHistory>> {
  /// The parameter `stokUuid` of this provider.
  String get stokUuid;
}

class _StokHistoryProviderElement
    extends AutoDisposeProviderElement<List<StokHistory>> with StokHistoryRef {
  _StokHistoryProviderElement(super.provider);

  @override
  String get stokUuid => (origin as StokHistoryProvider).stokUuid;
}

String _$stokListHash() => r'24706157a676f82fe5ee054dea9d8d8f970dc104';

/// See also [StokList].
@ProviderFor(StokList)
final stokListProvider =
    AutoDisposeNotifierProvider<StokList, List<Stok>>.internal(
  StokList.new,
  name: r'stokListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$stokListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StokList = AutoDisposeNotifier<List<Stok>>;
String _$stokSortNotifierHash() => r'bfd3c0944d089baf16241a8eae5a5c403dbe041d';

/// See also [StokSortNotifier].
@ProviderFor(StokSortNotifier)
final stokSortNotifierProvider =
    AutoDisposeNotifierProvider<StokSortNotifier, StokSort>.internal(
  StokSortNotifier.new,
  name: r'stokSortNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stokSortNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StokSortNotifier = AutoDisposeNotifier<StokSort>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
