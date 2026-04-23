import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servisio_core/core/utils/permission_constants.dart';

void main() {
  group('PermissionConstants', () {
    test('should have all required stock permissions', () {
      expect(PermissionConstants.stokCreate, equals('stok_create'));
      expect(PermissionConstants.stokRead, equals('stok_read'));
      expect(PermissionConstants.stokUpdateJumlah, equals('stok_update_jumlah'));
      expect(PermissionConstants.stokUpdateHargaBeli, equals('stok_update_harga_beli'));
      expect(PermissionConstants.stokUpdateHargaJual, equals('stok_update_harga_jual'));
      expect(PermissionConstants.stokUpdateMinStok, equals('stok_update_min_stok'));
      expect(PermissionConstants.stokDelete, equals('stok_delete'));
    });

    test('should have all required pelanggan permissions', () {
      expect(PermissionConstants.pelangganCreate, equals('pelanggan_create'));
      expect(PermissionConstants.pelangganRead, equals('pelanggan_read'));
      expect(PermissionConstants.pelangganUpdate, equals('pelanggan_update'));
      expect(PermissionConstants.pelangganDelete, equals('pelanggan_delete'));
    });

    test('should have all required transaksi permissions', () {
      expect(PermissionConstants.transaksiCreate, equals('transaksi_create'));
      expect(PermissionConstants.transaksiRead, equals('transaksi_read'));
      expect(PermissionConstants.transaksiUpdate, equals('transaksi_update'));
      expect(PermissionConstants.transaksiDelete, equals('transaksi_delete'));
      expect(PermissionConstants.transaksiCancel, equals('transaksi_cancel'));
    });

    test('should have all required staff permissions', () {
      expect(PermissionConstants.staffView, equals('staff_view'));
      expect(PermissionConstants.staffCreate, equals('staff_create'));
      expect(PermissionConstants.staffUpdate, equals('staff_update'));
      expect(PermissionConstants.staffDelete, equals('staff_delete'));
      expect(PermissionConstants.staffAssignRole, equals('staff_assign_role'));
    });

    test('should have all required laporan permissions', () {
      expect(PermissionConstants.laporanView, equals('laporan_view'));
      expect(PermissionConstants.laporanExport, equals('laporan_export'));
      expect(PermissionConstants.laporanPrint, equals('laporan_print'));
    });

    test('should have all required keuangan permissions', () {
      expect(PermissionConstants.keuanganView, equals('keuangan_view'));
      expect(PermissionConstants.keuanganEdit, equals('keuangan_edit'));
    });

    test('should have all required settings permissions', () {
      expect(PermissionConstants.settingsView, equals('settings_view'));
      expect(PermissionConstants.settingsUpdate, equals('settings_update'));
      expect(PermissionConstants.backupRestore, equals('backup_restore'));
    });

    test('allPermissions should contain all permission constants', () {
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.stokCreate));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.stokDelete));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.pelangganCreate));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.pelangganDelete));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.transaksiCreate));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.transaksiDelete));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.staffCreate));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.staffDelete));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.laporanView));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.keuanganView));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.settingsView));
      expect(PermissionConstants.allPermissions, contains(PermissionConstants.backupRestore));
    });

    group('Permission Categories', () {
      test('should have stok category with correct structure', () {
        final category = PermissionConstants.categories['stok'];
        expect(category, isNotNull);
        expect(category!.name, equals('Manajemen Stok'));
        expect(category.icon, equals(Icons.inventory));
        expect(category.order, equals(1));
        expect(category.permissions.length, equals(7));
      });

      test('should have pelanggan category', () {
        final category = PermissionConstants.categories['pelanggan'];
        expect(category, isNotNull);
        expect(category!.name, equals('Manajemen Pelanggan'));
        expect(category.order, equals(2));
      });

      test('should have transaksi category', () {
        final category = PermissionConstants.categories['transaksi'];
        expect(category, isNotNull);
        expect(category!.name, equals('Transaksi & Keuangan'));
        expect(category.order, equals(3));
      });

      test('should have staff category', () {
        final category = PermissionConstants.categories['staff'];
        expect(category, isNotNull);
        expect(category!.name, equals('Manajemen Staff'));
        expect(category.order, equals(4));
      });

      test('should have laporan category', () {
        final category = PermissionConstants.categories['laporan'];
        expect(category, isNotNull);
        expect(category!.name, equals('Laporan & Ekspor'));
        expect(category.order, equals(5));
      });

      test('should have settings category', () {
        final category = PermissionConstants.categories['settings'];
        expect(category, isNotNull);
        expect(category!.name, equals('Pengaturan Sistem'));
        expect(category.order, equals(6));
      });
    });

    group('Risk Levels', () {
      test('should correctly identify high risk permissions', () {
        final stokCategory = PermissionConstants.categories['stok'];
        final hargaJualPermission = stokCategory!.permissions.firstWhere(
          (p) => p.key == PermissionConstants.stokUpdateHargaJual,
        );
        expect(hargaJualPermission.isHighRisk, isTrue);
        expect(hargaJualPermission.riskLevel, equals(RiskLevel.high));
        expect(hargaJualPermission.riskColor, equals(Colors.red));
      });

      test('should correctly identify medium risk permissions', () {
        final stokCategory = PermissionConstants.categories['stok'];
        final hargaBeliPermission = stokCategory!.permissions.firstWhere(
          (p) => p.key == PermissionConstants.stokUpdateHargaBeli,
        );
        expect(hargaBeliPermission.isHighRisk, isFalse);
        expect(hargaBeliPermission.riskLevel, equals(RiskLevel.medium));
        expect(hargaBeliPermission.riskColor, equals(Colors.orange));
      });

      test('should correctly identify low risk permissions', () {
        final stokCategory = PermissionConstants.categories['stok'];
        final stokCreatePermission = stokCategory!.permissions.firstWhere(
          (p) => p.key == PermissionConstants.stokCreate,
        );
        expect(stokCreatePermission.isHighRisk, isFalse);
        expect(stokCreatePermission.riskLevel, equals(RiskLevel.low));
        expect(stokCreatePermission.riskColor, equals(Colors.grey));
      });
    });
  });
}
