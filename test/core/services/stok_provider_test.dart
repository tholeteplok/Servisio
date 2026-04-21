import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servisio_core/core/providers/stok_provider.dart';
import 'package:servisio_core/core/providers/objectbox_provider.dart';
import 'package:servisio_core/core/providers/sync_provider.dart';
import 'package:servisio_core/domain/entities/stok.dart';
import 'package:servisio_core/domain/entities/stok_history.dart';
import 'package:servisio_core/data/repositories/stok_repository.dart';
import 'package:servisio_core/data/repositories/stok_history_repository.dart';
import '../../mocks/manual_mocks.dart';

class FakeStokRepository extends Fake implements StokRepository {
  final List<Stok> _items = [];

  @override
  List<Stok> getAll() => _items.where((s) => !s.isDeleted).toList();

  @override
  Stok? getByUuid(String uuid) => _items.cast<Stok?>().firstWhere((s) => s?.uuid == uuid, orElse: () => null);

  @override
  int save(Stok stok) {
    if (stok.id == 0) stok.id = _items.length + 1;
    final idx = _items.indexWhere((s) => s.id == stok.id);
    if (idx >= 0) {
      _items[idx] = stok;
    } else {
      _items.add(stok);
    }
    return stok.id;
  }

  @override
  bool softDelete(int id) {
    final item = _items.firstWhere((s) => s.id == id, orElse: () => Stok(nama: '', kategori: '', jumlah: 0, hargaBeli: 0, hargaJual: 0));
    if (item.uuid.isNotEmpty) {
      item.isDeleted = true;
      return true;
    }
    return false;
  }
}

class FakeStokHistoryRepository extends Fake implements StokHistoryRepository {
  final List<StokHistory> _histories = [];

  @override
  int save(StokHistory object) {
    if (object.id == 0) object.id = _histories.length + 1;
    _histories.add(object);
    return object.id;
  }

  @override
  List<StokHistory> getAllForStok(String stokUuid) {
    return _histories.where((h) => h.stokUuid == stokUuid).toList();
  }
}

void main() {
  late ProviderContainer container;
  late FakeStokRepository stokRepo;
  late FakeStokHistoryRepository historyRepo;
  late FakeSyncWorker fakeSyncWorker;

  setUp(() {
    stokRepo = FakeStokRepository();
    historyRepo = FakeStokHistoryRepository();
    fakeSyncWorker = FakeSyncWorker();

    container = createContainer(
      overrides: [
        stokRepositoryProvider.overrideWith((ref) => stokRepo),
        stokHistoryRepositoryProvider.overrideWith((ref) => historyRepo),
        syncWorkerProvider.overrideWith((ref) => fakeSyncWorker),
        dbProvider.overrideWith((ref) => FakeObjectBoxProvider()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('StokListNotifier Tests', () {
    test('Initial state loads stok', () {
      stokRepo.save(Stok(nama: 'Oli', kategori: 'Sparepart', jumlah: 10, hargaBeli: 1000, hargaJual: 2000)..uuid = 'stok-1');
      
      final list = container.read(stokListProvider);
      
      expect(list.length, 1);
      expect(list.first.nama, 'Oli');
    });

    test('addItem creates stok and initial history', () async {
      final stok = Stok(nama: 'Busi', kategori: 'Sparepart', jumlah: 5, hargaBeli: 500, hargaJual: 1000)..uuid = 'stok-2';
      await container.read(stokListProvider.notifier).addItem(stok);

      final list = container.read(stokListProvider);
      expect(list.length, 1);
      
      final histories = historyRepo.getAllForStok('stok-2');
      expect(histories.length, 1);
      expect(histories.first.type, 'INITIAL');
    });

    test('restock increases quantity and records history', () async {
      stokRepo.save(Stok(nama: 'Ban', kategori: 'Part', jumlah: 2, hargaBeli: 1, hargaJual: 2)..uuid = 'stok-3');
      
      await container.read(stokListProvider.notifier).restock('stok-3', 3, 'Beli lagi');
      
      final list = container.read(stokListProvider);
      expect(list.first.jumlah, 5); // 2 + 3
      
      final histories = historyRepo.getAllForStok('stok-3');
      expect(histories.first.type, 'RESTOCK');
      expect(histories.first.quantityChange, 3);
    });

    test('deleteStok soft deletes item', () {
      final id = stokRepo.save(Stok(nama: 'DeleteMe', kategori: 'Part', jumlah: 1, hargaBeli: 1, hargaJual: 2)..uuid = 'stok-4');
      container.read(stokListProvider);

      container.read(stokListProvider.notifier).deleteStok(id);
      
      expect(container.read(stokListProvider).isEmpty, isTrue);
    });
  });
}

ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );
  addTearDown(container.dispose);
  return container;
}
