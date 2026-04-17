// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'objectbox_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dbInstanceHash() => r'3a91f6b2fc265eb8b30bc79d10724c9a7c1d77f2';

/// Provider that manages the ObjectBox instance.
/// It uses [Future] for initial setup and can be updated at runtime.
///
/// Copied from [DbInstance].
@ProviderFor(DbInstance)
final dbInstanceProvider =
    AsyncNotifierProvider<DbInstance, ObjectBoxProvider>.internal(
  DbInstance.new,
  name: r'dbInstanceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dbInstanceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DbInstance = AsyncNotifier<ObjectBoxProvider>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
