import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/domain/entities/expense.dart';
import 'package:servisio_core/domain/entities/debt_payment.dart';

void main() {
  group('Expense Debt Logic Tests', () {
    test('debtBalance should return 0 if debtStatus is null or LUNAS', () {
      final expenseNull = Expense(
        amount: 100000,
        category: 'OPERASIONAL',
        bengkelId: 'b1',
        debtStatus: null,
      );
      expect(expenseNull.debtBalance, 0);

      final expenseLunas = Expense(
        amount: 100000,
        category: 'STOK',
        bengkelId: 'b1',
        debtStatus: 'LUNAS',
      );
      expect(expenseLunas.debtBalance, 0);
    });

    test('debtBalance should calculate correctly with repayments (Expense)', () {
      final parentDebt = Expense(
        amount: 500000,
        category: 'STOK',
        bengkelId: 'b1',
        debtStatus: 'HUTANG',
      );

      // Add a repayment as an Expense
      final repayment = Expense(
        amount: 100000,
        category: 'CICILAN',
        bengkelId: 'b1',
      );
      parentDebt.repayments.add(repayment);

      expect(parentDebt.debtBalance, 400000);
      
      // Add another repayment
      final repayment2 = Expense(
        amount: 50000,
        category: 'CICILAN',
        bengkelId: 'b1',
      );
      parentDebt.repayments.add(repayment2);
      
      expect(parentDebt.debtBalance, 350000);
    });

    test('debtBalance should calculate correctly with DebtPayment entities', () {
      final parentDebt = Expense(
        amount: 1000000,
        category: 'STOK',
        bengkelId: 'b1',
        debtStatus: 'PARTIAL',
      );

      // Add a DebtPayment
      final payment = DebtPayment(
        amount: 200000,
        paymentMethod: 'TUNAI',
        paymentDate: DateTime.now(),
        bengkelId: 'b1',
      );
      parentDebt.debtPayments.add(payment);

      expect(parentDebt.debtBalance, 800000);
    });

    test('debtBalance should combine both repayments and debtPayments', () {
      final parentDebt = Expense(
        amount: 1000000,
        category: 'STOK',
        bengkelId: 'b1',
        debtStatus: 'PARTIAL',
      );

      // Repayment (Expense)
      parentDebt.repayments.add(Expense(amount: 100000, category: 'CICILAN', bengkelId: 'b1'));
      
      // DebtPayment
      parentDebt.debtPayments.add(DebtPayment(
        amount: 250000,
        paymentMethod: 'TRANSFER',
        paymentDate: DateTime.now(),
        bengkelId: 'b1',
      ));

      expect(parentDebt.debtBalance, 650000);
    });
  });
}
