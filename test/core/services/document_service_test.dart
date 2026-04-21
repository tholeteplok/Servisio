import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/services/document_service.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import 'package:servisio_core/domain/entities/sale.dart';
import '../../mocks/manual_mocks.dart';

void main() {
  late DocumentService documentService;
  late FakeDocumentActions fakeActions;

  setUp(() {
    fakeActions = FakeDocumentActions();
    documentService = DocumentService(actions: fakeActions);
  });

  group('DocumentService Tests', () {
    test('shareWhatsApp should launch WhatsApp URL', () async {
      final transaction = Transaction(
        uuid: 'tx-1',
        customerName: 'Budi',
        customerPhone: '08123',
        vehicleModel: 'Vario',
        vehiclePlate: 'B 1234 ABC',
      )..totalAmount = 100000;

      await documentService.shareWhatsApp(
        phone: '0812345678',
        transaction: transaction,
        bengkelName: 'Test Bengkel',
      );

      expect(fakeActions.lastLaunchedUrl.toString(), contains('whatsapp://send'));
      expect(fakeActions.lastLaunchedUrl.toString(), contains('62812345678'));
    });

    test('generateAndPrint should call printing layout', () async {
      final transaction = Transaction(
        uuid: 'tx-1',
        customerName: 'Budi',
        customerPhone: '08123',
        vehicleModel: 'Vario',
        vehiclePlate: 'B 1234 ABC',
      )..totalAmount = 100000;

      await documentService.generateAndPrint(
        transaction: transaction,
        bengkelName: 'Test Bengkel',
        isThermal: true,
      );

      expect(fakeActions.layoutCalled, isTrue);
    });

    test('shareWhatsApp for Sales should launch WhatsApp URL', () async {
      final sale = Sale(
        uuid: 's1',
        itemName: 'Oli',
        quantity: 1,
        totalPrice: 50000,
      );

      await documentService.shareWhatsApp(
        phone: '0855',
        sales: [sale],
        bengkelName: 'Test Bengkel',
      );

      expect(fakeActions.lastLaunchedUrl.toString(), contains('62855'));
    });
  });
}
