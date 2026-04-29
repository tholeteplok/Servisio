import 'package:cloud_firestore/cloud_firestore.dart';

/// Extension pada FirebaseFirestore untuk mempermudah akses ke struktur baru bertingkat.
extension FirestoreUserExtension on FirebaseFirestore {
  /// Reference ke dokumen user (pribadi): users/{userId}
  DocumentReference<Map<String, dynamic>> userDoc(String userId) =>
      collection('users').doc(userId);

  /// Reference ke koleksi workshops yang dimiliki user
  CollectionReference<Map<String, dynamic>> userWorkshops(String userId) =>
      userDoc(userId).collection('workshops');

  /// Reference ke dokumen workshop spesifik di bawah owner tertentu
  DocumentReference<Map<String, dynamic>> workshopDoc({
    required String ownerId,
    required String workshopId,
  }) =>
      userDoc(ownerId).collection('workshops').doc(workshopId);

  /// Reference ke koleksi operasional di dalam workshop (customers, inventory, dll)
  CollectionReference<Map<String, dynamic>> workshopCollection({
    required String ownerId,
    required String workshopId,
    required String collectionName,
  }) =>
      workshopDoc(ownerId: ownerId, workshopId: workshopId)
          .collection(collectionName);
}

/// Extension pada DocumentReference untuk akses subkoleksi yang lebih bersih
extension FirestoreDocumentExtension on DocumentReference<Map<String, dynamic>> {
  /// Navigasi ke subkoleksi dalam dokumen ini
  CollectionReference<Map<String, dynamic>> subCollection(String name) =>
      collection(name);

  /// Navigasi ke dokumen spesifik dalam subkoleksi
  DocumentReference<Map<String, dynamic>> subDoc({
    required String collectionName,
    required String docId,
  }) =>
      collection(collectionName).doc(docId);
}

/// Extension untuk bridging antara FirestorePaths (String) ke Firestore References
extension FirestorePathsExtension on FirebaseFirestore {
  /// Mendapatkan DocumentReference dari path string
  DocumentReference<Map<String, dynamic>> refFromPath(String path) => doc(path);

  /// Mendapatkan CollectionReference dari path string
  CollectionReference<Map<String, dynamic>> collectionFromPath(String path) =>
      collection(path);
}
