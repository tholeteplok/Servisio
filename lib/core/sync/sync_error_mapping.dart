import 'package:flutter/material.dart';
import 'circuit_breaker.dart'; // For error typing

/// 🚩 SyncErrorMessage — Map error types to human-readable actions.
/// Ensures the shop owner knows exactly what happened and what to do next.
class SyncErrorMessage {
  static String getMessage(DriveErrorType errorType, {String? details}) {
    return switch (errorType) {
      DriveErrorType.quotaExceeded => 
        'Penyimpanan penuh. Silakan hapus file atau tingkatkan ketersediaan penyimpanan Anda.',
      DriveErrorType.rateLimit => 
        'Terlalu banyak permintaan serentak. Sistem akan mencoba lagi secara otomatis dalam beberapa menit.',
      DriveErrorType.auth => 
        'Sesi login Anda telah kedaluwarsa. Silakan masuk kembali untuk melanjutkan sinkronisasi.',
      DriveErrorType.permission => 
        'Izin akses tidak ditemukan. Periksa kembali pengaturan hak akses akun Anda.',
      DriveErrorType.notFound => 
        'Data tidak ditemukan di server. Kemungkinan data telah dihapus dari perangkat lain.',
      DriveErrorType.server => 
        'Layanan sedang mengalami gangguan teknis. Sistem akan mencoba lagi nanti.',
      DriveErrorType.network => 
        'Koneksi internet tidak stabil. Pastikan perangkat Anda terhubung ke jaringan yang kuat.',
      DriveErrorType.unknown => 
        details ?? 'Terjadi kesalahan sistem saat sinkronisasi data.',
    };
  }

  static IconData getIcon(DriveErrorType errorType) {
    return switch (errorType) {
      DriveErrorType.quotaExceeded => Icons.cloud_off,
      DriveErrorType.rateLimit => Icons.timer,
      DriveErrorType.auth => Icons.lock_open,
      DriveErrorType.permission => Icons.block,
      DriveErrorType.notFound => Icons.delete_outline,
      DriveErrorType.server => Icons.dns,
      DriveErrorType.network => Icons.signal_wifi_off,
      DriveErrorType.unknown => Icons.error_outline,
    };
  }

  static Color getColor(DriveErrorType errorType) {
    return switch (errorType) {
      DriveErrorType.quotaExceeded => Colors.orange,
      DriveErrorType.rateLimit => Colors.amber,
      DriveErrorType.auth => Colors.redAccent,
      DriveErrorType.permission => Colors.red,
      DriveErrorType.notFound => Colors.grey,
      DriveErrorType.server => Colors.blueAccent,
      DriveErrorType.network => Colors.amber,
      DriveErrorType.unknown => Colors.grey,
    };
  }
}

