import '../../models/customer_model.dart';
import 'base_remote_datasource.dart';

class CustomerRemoteDatasource extends BaseRemoteDatasource {
  CustomerRemoteDatasource({required super.firestore});

  @override
  String get collectionName => 'customers';

  Future<List<CustomerModel>> getAll() async {
    final snapshot = await collectionRef
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => CustomerModel.fromFirestore(doc))
        .toList();
  }

  Future<CustomerModel?> getById(String customerId) async {
    final doc = await docRef(customerId).get();
    if (!doc.exists) return null;
    return CustomerModel.fromFirestore(doc);
  }

  Future<void> create(CustomerModel customer) async {
    await docRef(customer.id).set(customer.toFirestore());
  }

  Future<void> update(String customerId, Map<String, dynamic> data) async {
    await docRef(customerId).update(data);
  }

  Future<void> delete(String customerId) async {
    await docRef(customerId).delete();
  }
}
