import 'package:cloud_firestore/cloud_firestore.dart';

/// Base class untuk semua remote datasource.
/// Menyediakan akses ke koleksi dalam workshop aktif.
///
/// Subclass hanya perlu override `collectionName`.
/// Query otomatis mengarah ke:
/// users/{ownerId}/workshops/{activeWorkshopId}/{collectionName}

abstract class BaseRemoteDatasource {
  final FirebaseFirestore firestore;

  BaseRemoteDatasource({required this.firestore});

  /// Owner ID (pemilik bengkel) - di-set sebelum query
  String? ownerId;

  /// Workshop ID yang sedang aktif - di-set sebelum query
  String? activeWorkshopId;

  /// Nama koleksi (di-override oleh subclass)
  String get collectionName;

  /// Validasi bahwa ownerId dan workshopId sudah di-set
  void _ensureReady() {
    if (ownerId == null) {
      throw StateError('$runtimeType: ownerId belum di-set');
    }
    if (activeWorkshopId == null) {
      throw StateError('$runtimeType: activeWorkshopId belum di-set');
    }
  }

  /// Reference ke dokumen dalam koleksi workshop aktif
  DocumentReference<Map<String, dynamic>> docRef(String docId) {
    _ensureReady();
    return firestore
        .collection('users')
        .doc(ownerId!)
        .collection('workshops')
        .doc(activeWorkshopId!)
        .collection(collectionName)
        .doc(docId);
  }

  /// Reference ke koleksi dalam workshop aktif
  CollectionReference<Map<String, dynamic>> get collectionRef {
    _ensureReady();
    return firestore
        .collection('users')
        .doc(ownerId!)
        .collection('workshops')
        .doc(activeWorkshopId!)
        .collection(collectionName);
  }

  /// Reference ke subkoleksi dalam dokumen
  CollectionReference<Map<String, dynamic>> subCollectionRef({
    required String docId,
    required String subCollectionName,
  }) {
    _ensureReady();
    return docRef(docId).collection(subCollectionName);
  }
}
