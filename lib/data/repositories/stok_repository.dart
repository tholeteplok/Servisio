import '../../domain/entities/stok.dart';
import '../../objectbox.g.dart';

class StokRepository {
  final Box<Stok> _box;

  StokRepository(this._box);

  int save(Stok stok) {
    // 🛡️ Business Rule: Negative stock validation
    if (stok.jumlah < 0) {
      throw Exception("Jumlah stok tidak boleh negatif.");
    }

    // 🛡️ Business Rule: Price Integrity
    if (stok.hargaJual < stok.hargaBeli && stok.hargaJual > 0) {
      // Only warn if hargaJual is not 0 (0 might be a placeholder for services or draft items, 
      // but for Stok it usually means invalid if Beli > 0)
      throw Exception("Harga jual (${stok.hargaJual}) tidak boleh lebih rendah dari modal (${stok.hargaBeli}).");
    }

    // 🛡️ Logic Guard: Barcode/SKU Uniqueness
    if (stok.sku != null && stok.sku!.trim().isNotEmpty) {
      final existing = _box
          .query(Stok_.sku.equals(stok.sku!.trim()))
          .build()
          .findFirst();
      if (existing != null && existing.id != stok.id) {
        throw Exception("Barcode/SKU '${stok.sku}' sudah terdaftar di sistem.");
      }
    } else {
      // 🛡️ Logic Guard: Name Uniqueness (Case-insensitive & Trimmed)
      final cleanName = stok.nama.trim();
      final existingByName = _box
          .query(Stok_.nama.equals(cleanName, caseSensitive: false))
          .build()
          .findFirst();

      if (existingByName != null && existingByName.id != stok.id) {
        throw Exception(
          "Barang dengan nama '$cleanName' sudah ada di inventaris.",
        );
      }
    }

    stok.nama = stok.nama.trim();
    if (stok.sku != null) stok.sku = stok.sku!.trim();
    stok.updatedAt = DateTime.now();
    return _box.put(stok);
  }

  /// Get all stock items that are not soft-deleted
  List<Stok> getAll() {
    final query = _box.query(Stok_.isDeleted.equals(false)).build();
    final results = query.find();
    query.close();
    return results;
  }

  Stok? getByUuid(String uuid) {
    final query = _box.query(Stok_.uuid.equals(uuid)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  bool softDelete(int id) {
    final s = _box.get(id);
    if (s != null) {
      s.isDeleted = true;
      s.updatedAt = DateTime.now();
      _box.put(s);
      return true;
    }
    return false;
  }

  bool delete(int id) {
    return _box.remove(id);
  }

  List<Stok> getLowStockItems() {
    final query = _box.query(Stok_.isDeleted.equals(false)).build();
    final results = query
        .find()
        .where((item) => item.jumlah <= item.minStok)
        .toList();
    query.close();
    return results;
  }

  List<Stok> search(String query) {
    final searchBox = _box
        .query(
          (Stok_.nama
                  .contains(query, caseSensitive: false)
                  .or(Stok_.sku.contains(query, caseSensitive: false)))
              .and(Stok_.isDeleted.equals(false)),
        )
        .build();
    final results = searchBox.find();
    searchBox.close();
    return results;
  }

  /// Get all unique supplier names from non-deleted stock items
  List<String> getUniqueSuppliers() {
    final allStok = getAll();
    final suppliers = allStok
        .map((s) => s.supplierName?.trim())
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    suppliers.sort();
    return suppliers;
  }
}
