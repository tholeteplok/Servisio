import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import '../providers/objectbox_provider.dart';


class LocalBackupService {
  final ObjectBoxProvider _db;

  LocalBackupService(this._db);

  /// Exports specific data type to CSV for Excel compatibility.
  Future<void> exportToCsv(String type) async {
    List<List<dynamic>> rows = [];
    String filename = '';

    if (type == 'STOK') {
      filename = 'Laporan_Stok_${_timestamp()}.csv';
      rows.add([
        'Nama',
        'SKU',
        'Kategori',
        'Jumlah',
        'Min Stok',
        'Harga Beli',
        'Harga Jual',
      ]);
      for (var item in _db.stokBox.getAll()) {
        rows.add([
          item.nama,
          item.sku ?? '-',
          item.kategori,
          item.jumlah,
          item.minStok,
          item.hargaBeli,
          item.hargaJual,
        ]);
      }
    } else if (type == 'TRANS') {
      filename = 'Laporan_Transaksi_${_timestamp()}.csv';
      rows.add([
        'No Trx',
        'Tanggal',
        'Pelanggan',
        'Kendaraan',
        'Plat',
        'Status',
        'Total',
        'Metode Bayar',
      ]);
      for (var trx in _db.transactionBox.getAll()) {
        rows.add([
          trx.trxNumber,
          DateFormat('yyyy-MM-dd HH:mm').format(trx.createdAt),
          trx.customerName,
          trx.vehicleModel,
          trx.vehiclePlate,
          trx.status,
          trx.totalAmount,
          trx.paymentMethod ?? '-',
        ]);
      }
    } else if (type == 'PELANGGAN') {
      filename = 'Daftar_Pelanggan_${_timestamp()}.csv';
      rows.add(['Nama', 'Telepon', 'Alamat']);
      for (var p in _db.pelangganBox.getAll()) {
        rows.add([p.nama, p.telepon, p.alamat]);
      }
    }

    if (rows.isEmpty) return;

    String csvData = csv.encode(rows);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvData);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'ServisLog+ CSV Export ($type)');
  }

  String _timestamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());


}

