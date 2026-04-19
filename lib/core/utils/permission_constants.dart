import 'package:flutter/material.dart';

/// Permission Constants - Definisi semua permission dalam satu tempat
/// SEC-FIX: Dynamic Permission System untuk granular access control
class PermissionConstants {
  // Stok Permissions
  static const String stokCreate = 'stok_create';
  static const String stokRead = 'stok_read';
  static const String stokUpdateJumlah = 'stok_update_jumlah';
  static const String stokUpdateHargaBeli = 'stok_update_harga_beli';
  static const String stokUpdateHargaJual = 'stok_update_harga_jual';
  static const String stokUpdateMinStok = 'stok_update_min_stok';
  static const String stokDelete = 'stok_delete';

  // Pelanggan Permissions
  static const String pelangganCreate = 'pelanggan_create';
  static const String pelangganRead = 'pelanggan_read';
  static const String pelangganUpdate = 'pelanggan_update';
  static const String pelangganDelete = 'pelanggan_delete';

  // Transaksi Permissions
  static const String transaksiCreate = 'transaksi_create';
  static const String transaksiRead = 'transaksi_read';
  static const String transaksiUpdate = 'transaksi_update';
  static const String transaksiDelete = 'transaksi_delete';
  static const String transaksiCancel = 'transaksi_cancel';

  // Staff Permissions
  static const String staffView = 'staff_view';
  static const String staffCreate = 'staff_create';
  static const String staffUpdate = 'staff_update';
  static const String staffDelete = 'staff_delete';
  static const String staffAssignRole = 'staff_assign_role';

  // Laporan Permissions
  static const String laporanView = 'laporan_view';
  static const String laporanExport = 'laporan_export';
  static const String laporanPrint = 'laporan_print';

  // Keuangan Permissions
  static const String keuanganView = 'keuangan_view';
  static const String keuanganEdit = 'keuangan_edit';

  // Settings Permissions
  static const String settingsView = 'settings_view';
  static const String settingsUpdate = 'settings_update';
  static const String backupRestore = 'backup_restore';

  // Semua permission untuk owner
  static const Set<String> allPermissions = {
    stokCreate, stokRead, stokUpdateJumlah, stokUpdateHargaBeli,
    stokUpdateHargaJual, stokUpdateMinStok, stokDelete,
    pelangganCreate, pelangganRead, pelangganUpdate, pelangganDelete,
    transaksiCreate, transaksiRead, transaksiUpdate, transaksiDelete, transaksiCancel,
    staffView, staffCreate, staffUpdate, staffDelete, staffAssignRole,
    laporanView, laporanExport, laporanPrint,
    keuanganView, keuanganEdit,
    settingsView, settingsUpdate, backupRestore,
  };

  // Permission categories
  static final Map<String, PermissionCategory> categories = {
    'stok': const PermissionCategory(
      name: 'Manajemen Stok',
      icon: Icons.inventory,
      order: 1,
      permissions: [
        PermissionItem(stokCreate, 'Tambah Stok Baru',
            'Staff dapat menambahkan stok baru ke sistem', riskLevel: RiskLevel.low),
        PermissionItem(stokUpdateJumlah, 'Update Jumlah Stok',
            'Staff dapat mengurangi atau menambah jumlah stok', riskLevel: RiskLevel.low),
        PermissionItem(stokUpdateHargaBeli, 'Update Harga Beli',
            '⚠️ Staff dapat mengubah harga modal barang', riskLevel: RiskLevel.medium),
        PermissionItem(stokUpdateHargaJual, 'Update Harga Jual',
            '🔴 Staff dapat mengubah harga jual barang', riskLevel: RiskLevel.high),
        PermissionItem(stokUpdateMinStok, 'Update Minimal Stok',
            'Staff dapat mengubah batas minimal stok', riskLevel: RiskLevel.low),
        PermissionItem(stokDelete, 'Hapus Stok',
            '🔴 Staff dapat menghapus data stok permanen', riskLevel: RiskLevel.high),
      ],
    ),
    'pelanggan': const PermissionCategory(
      name: 'Manajemen Pelanggan',
      icon: Icons.people,
      order: 2,
      permissions: [
        PermissionItem(pelangganCreate, 'Tambah Pelanggan',
            'Staff dapat mendaftarkan pelanggan baru', riskLevel: RiskLevel.low),
        PermissionItem(pelangganUpdate, 'Update Pelanggan',
            'Staff dapat mengedit data pelanggan', riskLevel: RiskLevel.low),
        PermissionItem(pelangganDelete, 'Hapus Pelanggan',
            '🔴 Staff dapat menghapus data pelanggan', riskLevel: RiskLevel.high),
      ],
    ),
    'transaksi': const PermissionCategory(
      name: 'Transaksi & Keuangan',
      icon: Icons.receipt,
      order: 3,
      permissions: [
        PermissionItem(transaksiCreate, 'Buat Transaksi',
            'Staff dapat membuat nota/service', riskLevel: RiskLevel.low),
        PermissionItem(transaksiUpdate, 'Edit Transaksi',
            'Staff dapat mengubah item/service', riskLevel: RiskLevel.medium),
        PermissionItem(transaksiCancel, 'Batalkan Transaksi',
            '⚠️ Staff dapat membatalkan transaksi', riskLevel: RiskLevel.medium),
        PermissionItem(transaksiDelete, 'Hapus Transaksi',
            '🔴 Staff dapat menghapus data transaksi', riskLevel: RiskLevel.high),
        PermissionItem(keuanganView, 'Lihat Laporan Keuangan',
            'Staff dapat melihat laba/rugi', riskLevel: RiskLevel.medium),
        PermissionItem(keuanganEdit, 'Edit Data Keuangan',
            '🔴 Staff dapat memanipulasi laporan keuangan', riskLevel: RiskLevel.high),
      ],
    ),
    'staff': const PermissionCategory(
      name: 'Manajemen Staff',
      icon: Icons.badge,
      order: 4,
      permissions: [
        PermissionItem(staffView, 'Lihat Data Staff',
            'Staff dapat melihat data rekan kerja', riskLevel: RiskLevel.low),
        PermissionItem(staffCreate, 'Tambah Staff Baru',
            '⚠️ Staff dapat merekrut staff baru', riskLevel: RiskLevel.medium),
        PermissionItem(staffUpdate, 'Edit Data Staff',
            '⚠️ Staff dapat mengubah data rekan', riskLevel: RiskLevel.medium),
        PermissionItem(staffAssignRole, 'Assign Role ke Staff',
            '🔴 Staff dapat mengubah role staff lain', riskLevel: RiskLevel.high),
        PermissionItem(staffDelete, 'Hapus Staff',
            '🔴 Staff dapat menghapus data staff', riskLevel: RiskLevel.high),
      ],
    ),
    'laporan': const PermissionCategory(
      name: 'Laporan & Ekspor',
      icon: Icons.assessment,
      order: 5,
      permissions: [
        PermissionItem(laporanView, 'Lihat Laporan',
            'Staff dapat melihat semua laporan', riskLevel: RiskLevel.low),
        PermissionItem(laporanExport, 'Ekspor Data',
            '⚠️ Staff dapat mengekspor data ke luar', riskLevel: RiskLevel.medium),
        PermissionItem(laporanPrint, 'Cetak Laporan',
            'Staff dapat mencetak laporan', riskLevel: RiskLevel.low),
      ],
    ),
    'settings': const PermissionCategory(
      name: 'Pengaturan Sistem',
      icon: Icons.settings,
      order: 6,
      permissions: [
        PermissionItem(settingsView, 'Lihat Pengaturan',
            'Staff dapat melihat konfigurasi', riskLevel: RiskLevel.low),
        PermissionItem(settingsUpdate, 'Ubah Pengaturan',
            '🔴 Staff dapat mengubah konfigurasi sistem', riskLevel: RiskLevel.high),
        PermissionItem(backupRestore, 'Backup & Restore',
            '🔴 Staff dapat mengakses semua data', riskLevel: RiskLevel.high),
      ],
    ),
  };
}

enum RiskLevel { low, medium, high }

class PermissionCategory {
  final String name;
  final IconData icon;
  final int order;
  final List<PermissionItem> permissions;

  const PermissionCategory({
    required this.name,
    required this.icon,
    required this.order,
    required this.permissions,
  });
}

class PermissionItem {
  final String key;
  final String name;
  final String description;
  final RiskLevel riskLevel;

  const PermissionItem(this.key, this.name, this.description, {required this.riskLevel});

  bool get isHighRisk => riskLevel == RiskLevel.high;
  Color get riskColor => riskLevel == RiskLevel.high ? Colors.red :
                         riskLevel == RiskLevel.medium ? Colors.orange : Colors.grey;
}
