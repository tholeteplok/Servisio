import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/stok.dart';
import 'transaction_providers.dart';
import 'sale_providers.dart';
import 'stok_provider.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class TrendData {
  final String label;
  final int revenue;
  final int profit;

  TrendData({required this.label, required this.revenue, required this.profit});
}

class TopItem {
  final String name;
  final int count;
  final int revenue;

  TopItem({required this.name, required this.count, required this.revenue});
}

class StaffPerformance {
  final String name;
  final int count;
  final int revenue;
  final int totalBonus;

  StaffPerformance({
    required this.name,
    required this.count,
    required this.revenue,
    this.totalBonus = 0,
  });
}

class TransactionStats {
  final int todayPendapatan;
  final int yesterdayPendapatan;
  final int weeklyPendapatan;
  final int monthlyPendapatan;
  final int todayProfit;
  final int weeklyProfit;
  final int monthlyProfit;
  final int todayVisitorCount;
  final int todayActiveCount;
  final int todayWaitingCount;
  final int todayProcessingCount;
  final int lowStockCount;
  final int emptyStockCount;
  final int totalOrders;
  final List<TrendData> hourlyTrend;
  final List<TrendData> dailyTrend;
  final List<TrendData> weeklyTrend;
  final List<TopItem> topServices;
  final List<TopItem> topProducts;
  final List<StaffPerformance> staffPerformance;
  final Map<String, int> paymentStatsToday;
  final Map<String, int> paymentStats7D;
  final Map<String, int> paymentStats30D;

  TransactionStats({
    this.todayPendapatan = 0,
    this.yesterdayPendapatan = 0,
    this.weeklyPendapatan = 0,
    this.monthlyPendapatan = 0,
    this.todayProfit = 0,
    this.weeklyProfit = 0,
    this.monthlyProfit = 0,
    this.todayVisitorCount = 0,
    this.todayActiveCount = 0,
    this.todayWaitingCount = 0,
    this.todayProcessingCount = 0,
    this.lowStockCount = 0,
    this.emptyStockCount = 0,
    this.totalOrders = 0,
    this.hourlyTrend = const [],
    this.dailyTrend = const [],
    this.weeklyTrend = const [],
    this.topServices = const [],
    this.topProducts = const [],
    this.staffPerformance = const [],
    this.paymentStatsToday = const {},
    this.paymentStats7D = const {},
    this.paymentStats30D = const {},
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Business Logic Functions
// ─────────────────────────────────────────────────────────────────────────────

TransactionStats calculateStats(
  List<Transaction> transactions,
  List<Sale> sales,
  List<Stok> stokList,
) {
  DateTime now = DateTime.now();
  DateTime todayStart = DateTime(now.year, now.month, now.day);
  DateTime yesterdayStart = todayStart.subtract(const Duration(days: 1));
  DateTime weekStart = now.subtract(const Duration(days: 7));
  DateTime monthStart = DateTime(now.year, now.month, 1);

  int daily = 0, yesterday = 0, weekly = 0, monthly = 0;
  int todayProfitVal = 0, weeklyProfitVal = 0, monthlyProfitVal = 0;
  int todayVisitors = 0, todayWaiting = 0, todayProcessing = 0;

  Map<int, int> hourlyRevenueMap = {};
  Map<int, int> hourlyProfitMap = {};
  Map<String, int> dailyRevenueMap = {};
  Map<String, int> dailyProfitMap = {};

  Map<String, int> topServicesMap = {};
  Map<String, int> topServicesRevenueMap = {};
  Map<String, int> topProductsMap = {};
  Map<String, int> topProductsRevenueMap = {};
  Map<String, StaffPerformance> staffMap = {};

  Map<String, int> payToday = {};
  Map<String, int> pay7D = {};
  Map<String, int> pay30D = {};

  void updatePaymentStats(Map<String, int> map, String? method, int amount) {
    if (method == null || method.isEmpty) return;
    map[method] = (map[method] ?? 0) + amount;
  }

  // Process Transactions
  for (var t in transactions) {
    if (t.serviceStatus == ServiceStatus.lunas) {
      if (t.createdAt.isAfter(todayStart)) {
        daily += t.totalAmount;
        todayProfitVal += t.totalProfit;
        todayVisitors++;
        updatePaymentStats(payToday, t.paymentMethod, t.totalAmount);
      } else if (t.createdAt.isAfter(yesterdayStart)) {
        yesterday += t.totalAmount;
      }
      if (t.createdAt.isAfter(weekStart)) {
        weekly += t.totalAmount;
        weeklyProfitVal += t.totalProfit;
        updatePaymentStats(pay7D, t.paymentMethod, t.totalAmount);
      }
      if (t.createdAt.isAfter(monthStart)) {
        monthly += t.totalAmount;
        monthlyProfitVal += t.totalProfit;
        updatePaymentStats(pay30D, t.paymentMethod, t.totalAmount);
      }

      if (t.createdAt.isAfter(todayStart)) {
        int hour = t.createdAt.hour;
        hourlyRevenueMap[hour] = (hourlyRevenueMap[hour] ?? 0) + t.totalAmount;
        hourlyProfitMap[hour] = (hourlyProfitMap[hour] ?? 0) + t.totalProfit;
      }

      String dayKey = DateFormat('dd/MM').format(t.createdAt);
      dailyRevenueMap[dayKey] = (dailyRevenueMap[dayKey] ?? 0) + t.totalAmount;
      dailyProfitMap[dayKey] = (dailyProfitMap[dayKey] ?? 0) + t.totalProfit;

      for (var item in t.items) {
        if (item.isService) {
          topServicesMap[item.name] = (topServicesMap[item.name] ?? 0) + 1;
          topServicesRevenueMap[item.name] = (topServicesRevenueMap[item.name] ?? 0) + item.price;
        } else {
          topProductsMap[item.name] = (topProductsMap[item.name] ?? 0) + 1;
          topProductsRevenueMap[item.name] = (topProductsRevenueMap[item.name] ?? 0) + item.price;
        }
      }

      if (t.mechanic.target != null) {
        String sName = t.mechanic.target!.name;
        final existing = staffMap[sName];
        staffMap[sName] = StaffPerformance(
          name: sName,
          count: (existing?.count ?? 0) + 1,
          revenue: (existing?.revenue ?? 0) + t.totalAmount,
          totalBonus: (existing?.totalBonus ?? 0) + t.totalMechanicBonus,
        );
      }
    } else {
      if (t.createdAt.isAfter(todayStart)) {
        if (t.serviceStatus == ServiceStatus.antri) todayWaiting++;
        if (t.serviceStatus == ServiceStatus.dikerjakan) todayProcessing++;
      }
    }
  }

  // Process Sales
  for (var s in sales) {
    if (s.createdAt.isAfter(todayStart)) {
      daily += s.totalPrice;
      todayProfitVal += s.totalProfit;
      todayVisitors++;
      updatePaymentStats(payToday, s.paymentMethod, s.totalPrice);
    } else if (s.createdAt.isAfter(yesterdayStart)) {
      yesterday += s.totalPrice;
    }
    if (s.createdAt.isAfter(weekStart)) {
      weekly += s.totalPrice;
      weeklyProfitVal += s.totalProfit;
      updatePaymentStats(pay7D, s.paymentMethod, s.totalPrice);
    }
    if (s.createdAt.isAfter(monthStart)) {
      monthly += s.totalPrice;
      monthlyProfitVal += s.totalProfit;
      updatePaymentStats(pay30D, s.paymentMethod, s.totalPrice);
    }

    String dayKey = DateFormat('dd/MM').format(s.createdAt);
    dailyRevenueMap[dayKey] = (dailyRevenueMap[dayKey] ?? 0) + s.totalPrice;
    dailyProfitMap[dayKey] = (dailyProfitMap[dayKey] ?? 0) + s.totalProfit;

    topProductsMap[s.itemName] = (topProductsMap[s.itemName] ?? 0) + 1;
    topProductsRevenueMap[s.itemName] = (topProductsRevenueMap[s.itemName] ?? 0) + s.totalPrice;
  }

  List<TrendData> hourlyTrend = List.generate(24, (h) => TrendData(
    label: '$h:00',
    revenue: hourlyRevenueMap[h] ?? 0,
    profit: hourlyProfitMap[h] ?? 0,
  ));

  // Prepare Weekly Trend (Exactly Last 7 Days, one bar per day)
  List<TrendData> weeklyTrend = [];
  for (int i = 6; i >= 0; i--) {
    DateTime d = now.subtract(Duration(days: i));
    String key = DateFormat('dd/MM').format(d);
    weeklyTrend.add(TrendData(
      label: key,
      revenue: dailyRevenueMap[key] ?? 0,
      profit: dailyProfitMap[key] ?? 0,
    ));
  }

  // Prepare Daily Trend (Full History, sorted)
  final dailyTrendEntries = dailyRevenueMap.entries.toList()
    ..sort((a, b) {
      final aParts = a.key.split('/');
      final bParts = b.key.split('/');
      final aDate = DateTime(now.year, int.parse(aParts[1]), int.parse(aParts[0]));
      final bDate = DateTime(now.year, int.parse(bParts[1]), int.parse(bParts[0]));
      return aDate.compareTo(bDate);
    });

  List<TrendData> dailyTrend = dailyTrendEntries.map((e) => TrendData(
    label: e.key,
    revenue: e.value,
    profit: dailyProfitMap[e.key] ?? 0,
  )).toList();


  List<TopItem> topServices = topServicesMap.entries
      .map((e) => TopItem(name: e.key, count: e.value, revenue: topServicesRevenueMap[e.key] ?? 0))
      .toList()..sort((a, b) => b.count.compareTo(a.count));

  List<TopItem> topProducts = topProductsMap.entries
      .map((e) => TopItem(name: e.key, count: e.value, revenue: topProductsRevenueMap[e.key] ?? 0))
      .toList()..sort((a, b) => b.count.compareTo(a.count));

  List<StaffPerformance> staffPerformance = staffMap.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));


  return TransactionStats(
    todayPendapatan: daily,
    yesterdayPendapatan: yesterday,
    weeklyPendapatan: weekly,
    monthlyPendapatan: monthly,
    todayProfit: todayProfitVal,
    weeklyProfit: weeklyProfitVal,
    monthlyProfit: monthlyProfitVal,
    todayVisitorCount: todayVisitors,
    todayActiveCount: todayWaiting + todayProcessing,
    todayWaitingCount: todayWaiting,
    todayProcessingCount: todayProcessing,
    lowStockCount: stokList.where((s) => s.isLowStock).length,
    emptyStockCount: stokList.where((s) => s.jumlah <= 0).length,
    totalOrders: transactions.length + sales.length,
    hourlyTrend: hourlyTrend,
    dailyTrend: dailyTrend,
    weeklyTrend: weeklyTrend,
    topServices: topServices,

    topProducts: topProducts,
    staffPerformance: staffPerformance,
    paymentStatsToday: payToday,
    paymentStats7D: pay7D,
    paymentStats30D: pay30D,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 📡 Standard Providers
// ─────────────────────────────────────────────────────────────────────────────

final statsProvider = Provider<TransactionStats>((ref) {
  final transactionListAsync = ref.watch(transactionListProvider);
  final saleListAsync = ref.watch(saleListProvider);
  final stokList = ref.watch(stokListProvider);
  
  final defaultStats = TransactionStats(
    lowStockCount: stokList.where((s) => s.isLowStock).length,
    emptyStockCount: stokList.where((s) => s.jumlah <= 0).length,
  );
  
  // Use .when for cleaner logic in standard Providers
  return transactionListAsync.when(
    data: (transactions) => saleListAsync.maybeWhen(
      data: (sales) => calculateStats(transactions, sales, stokList),
      orElse: () => defaultStats,
    ),
    loading: () => defaultStats,
    error: (e, s) => defaultStats,
  );
});
