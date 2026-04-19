import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../providers/objectbox_provider.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/service_master.dart';

import 'package:flutter/foundation.dart';
import 'encryption_service.dart';

class BackupService {
  final ObjectBoxProvider _db;
  final EncryptionService _encryption;

  BackupService(this._db, this._encryption);

  /// Export to JSON with optional encryption of PII fields.
  /// If [userPin] and [bengkelId] are provided, PII fields are encrypted.
  Future<String?> exportToJson({String? userPin, String? bengkelId}) async {
    try {
      final isEncrypted = userPin != null && bengkelId != null;
      encrypt.Key? backupKey;
      
      if (isEncrypted) {
        backupKey = await _encryption.deriveKey(userPin, bengkelId);
      }
      
      final data = {
        'metadata': {
          'version': '1.1.0',
          'exportedAt': DateTime.now().toIso8601String(),
          'appName': 'ServisLog+',
          'isEncrypted': isEncrypted,
          'bengkelId': bengkelId, // Stored to allow deriving key correctly during import
        },
        'pelanggan': _db.pelangganBox
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'nama': _encryptField(e.nama, isEncrypted, backupKey),
                'telepon': _encryptField(e.telepon, isEncrypted, backupKey),
                'alamat': _encryptField(e.alamat, isEncrypted, backupKey),
                'catatan': e.catatan,
                'createdAt': e.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'staff': _db.store
            .box<Staff>()
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'name': _encryptField(e.name, isEncrypted, backupKey),
                'role': e.role,
                'phoneNumber': _encryptField(e.phoneNumber, isEncrypted, backupKey),
                'isActive': e.isActive,
                'createdAt': e.createdAt.toIso8601String(),
              },
            )
            .toList(),
        // ... (other fields don't have PII usually, but let's be consistent)
        'service_master': _db.store
            .box<ServiceMaster>()
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'name': e.name,
                'category': e.category,
                'basePrice': e.basePrice,
              },
            )
            .toList(),
        'stok': _db.stokBox
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'nama': e.nama,
                'sku': e.sku,
                'jumlah': e.jumlah,
                'hargaBeli': e.hargaBeli,
                'hargaJual': e.hargaJual,
                'kategori': e.kategori,
                'minStok': e.minStok,
              },
            )
            .toList(),
        'vehicle': _db.store
            .box<Vehicle>()
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'plate': e.plate,
                'model': e.model,
                'color': e.color,
                'year': e.year,
                'vin': _encryptField(e.vin, isEncrypted, backupKey),
                'ownerUuid': e.owner.target?.uuid,
              },
            )
            .toList(),
        'transaction': _db.transactionBox
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'trxNumber': e.trxNumber,
                'customerName': _encryptField(e.customerName, isEncrypted, backupKey),
                'customerPhone': _encryptField(e.customerPhone, isEncrypted, backupKey),
                'vehicleModel': e.vehicleModel,
                'vehiclePlate': e.vehiclePlate,
                'totalAmount': e.totalAmount,
                'statusValue': e.statusValue,
                'paymentMethod': e.paymentMethod,
                'createdAt': e.createdAt.toIso8601String(),
                'pelangganUuid': e.pelanggan.target?.uuid,
                'vehicleUuid': e.vehicle.target?.uuid,
                'mechanicUuid': e.mechanic.target?.uuid,
                'items': e.items
                    .map(
                      (it) => {
                        'uuid': it.uuid,
                        'name': it.name,
                        'price': it.price,
                        'quantity': it.quantity,
                        'subtotal': it.subtotal,
                        'isService': it.isService,
                        'stokUuid': it.stok.target?.uuid,
                        'serviceUuid': it.serviceMaster.target?.uuid,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
        'sale': _db.saleBox
            .getAll()
            .map(
              (e) => {
                'uuid': e.uuid,
                'customerName': _encryptField(e.customerName, isEncrypted, backupKey),
                'totalPrice': e.totalPrice,

                'paymentMethod': e.paymentMethod,
                'createdAt': e.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'stok_history': _db.stokHistoryBox
            .getAll()
            .map(
              (e) => {
                'id': e.id,
                'stokUuid': e.stokUuid,
                'type': e.type,
                'quantityChange': e.quantityChange,
                'previousQuantity': e.previousQuantity,
                'newQuantity': e.newQuantity,
                'note': e.note,
                'createdAt': e.createdAt.toIso8601String(),
              },
            )
            .toList(),
      };

      final jsonString = jsonEncode(data);
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = isEncrypted 
          ? 'ServisLog_Backup_SECURE_$dateStr.json'
          : 'ServisLog_Backup_$dateStr.json';
          
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: isEncrypted ? '🔐 ServisLog+ Secure Backup' : 'ServisLog+ Data Backup');
      return dateStr;
    } catch (e) {
      debugPrint('Backup Export Error: $e');
      rethrow;
    }
  }

  /// Import from JSON with decryption support. (Audit K-1)
  Future<Map<String, dynamic>> importFromJson(String jsonContent, {String? userPin}) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final metadata = data['metadata'] as Map<String, dynamic>?;
      
      bool isEncrypted = metadata?['isEncrypted'] ?? false;
      String? bengkelId = metadata?['bengkelId']?.toString();

      if (isEncrypted) {
        if (userPin == null || bengkelId == null) {
          throw Exception('Backup terenkripsi memerlukan PIN dan Bengkel ID.');
        }

        final backupKey = await _encryption.deriveKey(userPin, bengkelId);
        
        // Decrypt PII in Pelanggan
        final pelanggan = data['pelanggan'] as List?;
        pelanggan?.forEach((p) {
          p['nama'] = _encryption.decryptTextWithKey(p['nama'], backupKey);
          p['telepon'] = _encryption.decryptTextWithKey(p['telepon'], backupKey);
          p['alamat'] = _encryption.decryptTextWithKey(p['alamat'], backupKey);
        });

        // Decrypt PII in Staff
        final staff = data['staff'] as List?;
        staff?.forEach((s) {
          s['name'] = _encryption.decryptTextWithKey(s['name'], backupKey);
          s['phoneNumber'] = _encryption.decryptTextWithKey(s['phoneNumber'], backupKey);
        });

        // Decrypt PII in Vehicle
        final vehicle = data['vehicle'] as List?;
        vehicle?.forEach((v) {
          if (v['vin'] != null) {
            v['vin'] = _encryption.decryptTextWithKey(v['vin'], backupKey);
          }
        });
      }

      return data;
    } catch (e) {
      debugPrint('Backup Import Error: $e');
      rethrow;
    }
  }

  /// Safe encryption helper
  String _encryptField(String? value, bool isEncrypted, encrypt.Key? key) {
    if (value == null || value.isEmpty) return '';
    if (!isEncrypted || key == null) return value;
    return _encryption.encryptTextWithKey(value, key);
  }
}

