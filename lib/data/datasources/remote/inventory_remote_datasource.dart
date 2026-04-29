import '../../models/inventory_model.dart';
import 'base_remote_datasource.dart';

class InventoryRemoteDatasource extends BaseRemoteDatasource {
  InventoryRemoteDatasource({required super.firestore});

  @override
  String get collectionName => 'inventory';

  /// Ambil semua inventory
  Future<List<InventoryModel>> getAll() async {
    final snapshot = await collectionRef
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => InventoryModel.fromFirestore(doc))
        .toList();
  }

  /// Ambil satu item
  Future<InventoryModel?> getById(String itemId) async {
    final doc = await docRef(itemId).get();
    if (!doc.exists) return null;
    return InventoryModel.fromFirestore(doc);
  }

  /// Buat item baru
  Future<void> create(InventoryModel item) async {
    await docRef(item.id).set(item.toFirestore());
  }

  /// Update item
  Future<void> update(String itemId, Map<String, dynamic> data) async {
    await docRef(itemId).update(data);
  }

  /// Hapus item
  Future<void> delete(String itemId) async {
    await docRef(itemId).delete();
  }

  /// Tambah stock log (subcollection)
  Future<void> addStockLog({
    required String inventoryId,
    required Map<String, dynamic> logData,
  }) async {
    await subCollectionRef(
      docId: inventoryId,
      subCollectionName: 'stock_logs',
    ).add(logData);
  }
}
