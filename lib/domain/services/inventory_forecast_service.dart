/// Enum untuk kategori status stok berdasarkan prediksi.
enum StockStatus {
  healthy,
  lowStock,
  reorderNow,
  critical,
  outOfStock
}

/// Service untuk memprediksi kebutuhan stok menggunakan metode Reorder Point (ROP).
class InventoryForecastService {
  
  /// Menghitung status stok saat ini berdasarkan parameter prediksi.
  /// Reorder Point (ROP) = (Konsumsi Harian Rata-rata × Lead Time) + Safety Stock
  StockStatus getStockStatus({
    required int currentStock,
    required double avgDailyConsumption,
    int leadTimeDays = 3,      // Lead time standar 3 hari
    double safetyStock = 5.0,  // Safety stock default 5 unit
  }) {
    if (currentStock <= 0) return StockStatus.outOfStock;
    
    final reorderPoint = (avgDailyConsumption * leadTimeDays) + safetyStock;
    
    // Status Berdasarkan Threshold:
    // 1. Critical: Stok sudah menyentuh atau dibawah safety stock buffer.
    if (currentStock <= safetyStock) return StockStatus.critical;
    
    // 2. Reorder Now: Stok sudah menyentuh Reorder Point.
    if (currentStock <= reorderPoint) return StockStatus.reorderNow;
    
    // 3. Low Stock: Stok mendekati Reorder Point (margin 50%).
    if (currentStock <= (1.5 * reorderPoint)) return StockStatus.lowStock;
    
    // 4. Healthy: Stok mencukupi kebutuhan operasional.
    return StockStatus.healthy;
  }

  /// Label human-readable untuk UI.
  String getStatusLabel(StockStatus status) {
    switch (status) {
      case StockStatus.healthy: return 'Healthy';
      case StockStatus.lowStock: return 'Low Stock';
      case StockStatus.reorderNow: return 'Reorder Now';
      case StockStatus.critical: return 'Critical';
      case StockStatus.outOfStock: return 'Out of Stock';
    }
  }
}
