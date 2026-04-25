import '../../objectbox.g.dart';
import '../../domain/entities/debt_payment.dart';

class DebtPaymentRepository {
  final Box<DebtPayment> _box;

  DebtPaymentRepository(this._box);

  int save(DebtPayment payment) {
    return _box.put(payment);
  }

  List<DebtPayment> getByExpenseId(int expenseId) {
    final query = _box
        .query(DebtPayment_.expense.equals(expenseId))
        .order(DebtPayment_.paymentDate, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  List<DebtPayment> getBySupplierId(int supplierId) {
    final query = _box
        .query(DebtPayment_.supplier.equals(supplierId))
        .order(DebtPayment_.paymentDate, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }
  
  List<DebtPayment> getAll(String bengkelId) {
    final query = _box
        .query(DebtPayment_.bengkelId.equals(bengkelId))
        .order(DebtPayment_.paymentDate, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results;
  }
}

