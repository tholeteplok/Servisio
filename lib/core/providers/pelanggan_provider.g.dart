// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pelanggan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pelangganRepositoryHash() =>
    r'68bc1a3993531308b3049ac21143ee6a528cc8cf';

/// See also [pelangganRepository].
@ProviderFor(pelangganRepository)
final pelangganRepositoryProvider =
    AutoDisposeProvider<PelangganRepository>.internal(
  pelangganRepository,
  name: r'pelangganRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pelangganRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PelangganRepositoryRef = AutoDisposeProviderRef<PelangganRepository>;
String _$pelangganListHash() => r'0dcbc9e7cab62fd85e524ed340283efc827c431a';

/// See also [PelangganList].
@ProviderFor(PelangganList)
final pelangganListProvider =
    AutoDisposeNotifierProvider<PelangganList, List<Pelanggan>>.internal(
  PelangganList.new,
  name: r'pelangganListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pelangganListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PelangganList = AutoDisposeNotifier<List<Pelanggan>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
