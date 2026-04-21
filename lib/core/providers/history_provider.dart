import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import 'package:flutter/material.dart';
import '../constants/app_icons.dart';
import 'transaction_providers.dart';
import 'sale_providers.dart';
import 'navigation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 📊 History Models
// ─────────────────────────────────────────────────────────────────────────────

/// Filter state for History
class HistoryFilter {
  final DateTimeRange? dateRange;
  final String type; // 'ALL', 'SERVICE', 'SALE'
  final String paymentMethod; // 'ALL', 'Tunai', 'QRIS', 'Transfer'

  HistoryFilter({
    this.dateRange,
    this.type = 'ALL',
    this.paymentMethod = 'ALL',
  });

  HistoryFilter copyWith({
    DateTimeRange? dateRange,
    String? type,
    String? paymentMethod,
    bool clearDateRange = false,
  }) {
    return HistoryFilter(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

/// Data structure for a unified history item
class HistoryItemData {
  final String id;
  final String title;
  final String subtitle;
  final String trxNumber;
  final int amount;
  final DateTime date;
  final String type;
  final String status;
  final IconData icon;

  HistoryItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.trxNumber,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    required this.icon,
  });
}

class HistoryState {
  final List<HistoryItemData> items;
  final bool isLoading;
  final bool hasMore;
  final int transactionOffset;
  final int saleOffset;

  HistoryState({
    required this.items,
    this.isLoading = false,
    this.hasMore = true,
    this.transactionOffset = 0,
    this.saleOffset = 0,
  });

  HistoryState copyWith({
    List<HistoryItemData>? items,
    bool? isLoading,
    bool? hasMore,
    int? transactionOffset,
    int? saleOffset,
  }) {
    return HistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      transactionOffset: transactionOffset ?? this.transactionOffset,
      saleOffset: saleOffset ?? this.saleOffset,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🕹️ Notifiers
// ─────────────────────────────────────────────────────────────────────────────

class HistoryFilterNotifier extends StateNotifier<HistoryFilter> {
  HistoryFilterNotifier() : super(HistoryFilter());

  void setFilter(HistoryFilter filter) => state = filter;
  void update(HistoryFilter Function(HistoryFilter) cb) => state = cb(state);
  
  void updateFilter({
    DateTimeRange? dateRange,
    String? type,
    String? paymentMethod,
    bool clearDateRange = false,
  }) {
    state = state.copyWith(
      dateRange: dateRange,
      type: type,
      paymentMethod: paymentMethod,
      clearDateRange: clearDateRange,
    );
  }
}

class HistorySearchQueryNotifier extends StateNotifier<String> {
  HistorySearchQueryNotifier(Ref ref) : super('') {
    ref.listen(navigationProvider, (previous, next) {
      if (next != 3) state = '';
    });
  }
  void set(String query) => state = query;
}

class HistoryListNotifier extends StateNotifier<HistoryState> {
  final Ref ref;
  static const int pageSize = 10;

  HistoryListNotifier(this.ref) : super(HistoryState(items: [])) {
    // Initial fetch triggered by UI or manually
  }

  HistoryState _fetchItems(int tOffset, int sOffset, List<HistoryItemData> existingItems) {
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final saleRepo = ref.read(saleRepositoryProvider);
    final filter = ref.read(historyFilterNotifierProvider);

    final newTransactions = transactionRepo.getAll(limit: pageSize, offset: tOffset);
    final newSales = saleRepo.getAll(limit: pageSize, offset: sOffset);

    final List<HistoryItemData> newItems = [
      ...newTransactions
          .where((t) => t.serviceStatus == ServiceStatus.lunas)
          .where((t) {
            if (filter.type == 'SALE') return false;
            if (filter.paymentMethod != 'ALL' && t.paymentMethod != filter.paymentMethod) return false;
            if (filter.dateRange != null) {
              if (t.createdAt.isBefore(filter.dateRange!.start) ||
                  t.createdAt.isAfter(filter.dateRange!.end.add(const Duration(days: 1)))) {
                return false;
              }
            }
            return true;
          })
          .map((t) => HistoryItemData(
                id: t.uuid,
                title: t.vehicleModel,
                subtitle: t.items.isEmpty ? 'Detail Servis' : t.items.map((i) => i.name).join(', '),
                trxNumber: t.trxNumber,
                amount: t.totalAmount,
                date: t.createdAt,
                type: 'SERVICE',
                status: 'PAID',
                icon: AppIcons.service,
              )),
      ...newSales
          .where((s) {
            if (filter.type == 'SERVICE') return false;
            if (filter.paymentMethod != 'ALL' && s.paymentMethod != filter.paymentMethod) return false;
            if (filter.dateRange != null) {
              if (s.createdAt.isBefore(filter.dateRange!.start) ||
                  s.createdAt.isAfter(filter.dateRange!.end.add(const Duration(days: 1)))) {
                return false;
              }
            }
            return true;
          })
          .map((s) => HistoryItemData(
                id: s.uuid,
                title: s.itemName,
                subtitle: 'Penjualan Langsung',
                trxNumber: s.trxNumber,
                amount: s.totalPrice,
                date: s.createdAt,
                type: 'SALE',
                status: 'PAID',
                icon: Icons.shopping_basket_rounded,
              )),
    ];

    final combined = [...existingItems, ...newItems];
    combined.sort((a, b) => b.date.compareTo(a.date));

    return HistoryState(
      items: combined,
      isLoading: false,
      hasMore: newTransactions.length == pageSize || newSales.length == pageSize,
      transactionOffset: tOffset + newTransactions.length,
      saleOffset: sOffset + newSales.length,
    );
  }

  Future<void> loadInitial() async {
    state = _fetchItems(0, 0, []);
  }

  void loadMore() {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    state = _fetchItems(state.transactionOffset, state.saleOffset, state.items);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final historyFilterNotifierProvider = StateNotifierProvider<HistoryFilterNotifier, HistoryFilter>((ref) {
  return HistoryFilterNotifier();
});

final historySearchActiveProvider = StateProvider<bool>((ref) => false);

final historySearchQueryProvider = StateNotifierProvider<HistorySearchQueryNotifier, String>((ref) {
  return HistorySearchQueryNotifier(ref);
});

final historyListProvider = StateNotifierProvider<HistoryListNotifier, HistoryState>((ref) {
  // Reset when filters change
  ref.watch(historyFilterNotifierProvider);
  ref.watch(transactionListProvider);
  ref.watch(saleListProvider);
  
  final notifier = HistoryListNotifier(ref);
  notifier.loadInitial();
  return notifier;
});
