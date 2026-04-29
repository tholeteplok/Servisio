import '../../models/transaction_model.dart';
import 'base_remote_datasource.dart';

class TransactionRemoteDatasource extends BaseRemoteDatasource {
  TransactionRemoteDatasource({required super.firestore});

  @override
  String get collectionName => 'transactions';

  Future<List<TransactionModel>> getAll() async {
    final snapshot = await collectionRef
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
  }

  Future<TransactionModel?> getById(String trxId) async {
    final doc = await docRef(trxId).get();
    if (!doc.exists) return null;
    return TransactionModel.fromFirestore(doc);
  }

  Future<void> create(TransactionModel trx) async {
    await docRef(trx.id).set(trx.toFirestore());
  }

  Future<void> update(String trxId, Map<String, dynamic> data) async {
    await docRef(trxId).update(data);
  }

  /// Tambah status log (subcollection)
  Future<void> addStatusLog({
    required String transactionId,
    required Map<String, dynamic> logData,
  }) async {
    await subCollectionRef(
      docId: transactionId,
      subCollectionName: 'status_logs',
    ).add(logData);
  }
}
