import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the active tab in KatalogScreen (0: Barang, 1: Jasa, 2: Mobil)
class KatalogActiveTabNotifier extends StateNotifier<int> {
  KatalogActiveTabNotifier() : super(0);
  void set(int index) => state = index;
}

final katalogActiveTabProvider = StateNotifierProvider<KatalogActiveTabNotifier, int>((ref) {
  return KatalogActiveTabNotifier();
});

