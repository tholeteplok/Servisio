// ignore_for_file: avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/history_provider.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/domain/entities/transaction.dart';
import '../test/mocks/manual_mocks.dart';

void main() async {
  final fakeDb = FakeObjectBoxProvider();
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(fakeDb),
    ],
  );

  final now = DateTime.now();
  final tx = Transaction(
    uuid: 'tx-1',
    trxNumber: 'TX-001',
    customerName: 'Budi',
    customerPhone: '08123',
    vehicleModel: 'Vario',
    vehiclePlate: 'B 1234',
  )
    ..totalAmount = 100000
    ..serviceStatus = ServiceStatus.lunas
    ..createdAt = now;
  fakeDb.transactionBox.put(tx);
  
  print('Transactions in box: ${fakeDb.transactionBox.getAll().length}');

  container.read(historyFilterNotifierProvider.notifier).updateFilter(type: 'SERVICE');
  
  // Give it a microtask
  await Future.microtask(() {});

  final state = container.read(historyListProvider);
  print('History items: ${state.items.length}');
  for (var item in state.items) {
    print(' - ${item.id} (${item.type})');
  }
}
