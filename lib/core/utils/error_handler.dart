import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

// ─────────────────────────────────────────────────────────────
// ERROR HANDLER — Centralized (Phase 4 — UX)
// Mengubah error teknis menjadi pesan bahasa Indonesia yang
// bisa ditindaklanjuti oleh pengguna (terutama staf bengkel).
// ─────────────────────────────────────────────────────────────

/// Struktur pesan error yang actionable
class AppError {
  final String title;
  final String message;
  final String? action; // Langkah yang bisa dilakukan pengguna
  final ErrorCategory category;

  const AppError({
    required this.title,
    required this.message,
    this.action,
    required this.category,
  });

  @override
  String toString() => '[$category] $title: $message';
}

/// Kategori error untuk menentukan ikon dan warna di UI
enum ErrorCategory {
  network,      // Masalah koneksi internet
  auth,         // Masalah autentikasi / sesi
  permission,   // Tidak punya izin
  data,         // Masalah data (gagal simpan, stok kosong, dll)
  storage,      // Masalah penyimpanan lokal
  sync,         // Masalah sinkronisasi
  unknown,      // Error tidak dikenal
}

class AppErrorHandler {
  AppErrorHandler._();

  /// Konversi exception apa saja menjadi [AppError] yang user-friendly.
  static AppError from(dynamic error, {String? context}) {
    appLogger.warning('Error handled', context: context, error: error);

    // ── Firebase Auth Errors ──────────────────────────────────
    if (error is FirebaseAuthException) {
      return _fromFirebaseAuth(error);
    }

    // ── Firebase Firestore Errors ────────────────────────────
    if (error is FirebaseException) {
      return _fromFirestore(error);
    }

    // ── Network / Socket Errors ───────────────────────────────
    if (error is SocketException) {
      return const AppError(
        title: 'Gagal Terhubung',
        message: 'Perangkat tidak dapat terhubung ke Internet.',
        action: 'Periksa koneksi WiFi atau data seluler Anda, lalu coba lagi.',
        category: ErrorCategory.network,
      );
    }

    if (error is TimeoutException) {
      return const AppError(
        title: 'Koneksi Lambat',
        message: 'Permintaan memakan waktu terlalu lama.',
        action: 'Pastikan sinyal internet stabil. Coba lagi dalam beberapa detik.',
        category: ErrorCategory.network,
      );
    }

    // ── Permission / Access Errors ────────────────────────────
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission-denied') || errorStr.contains('unauthorized')) {
      return const AppError(
        title: 'Tidak Punya Izin',
        message: 'Akun Anda tidak memiliki akses untuk melakukan tindakan ini.',
        action: 'Hubungi Owner bengkel untuk mengatur izin Anda.',
        category: ErrorCategory.permission,
      );
    }

    // ── Stok Insufficient Error ───────────────────────────────
    if (errorStr.contains('stok') && errorStr.contains('tidak mencukupi')) {
      return AppError(
        title: 'Stok Tidak Cukup',
        message: error.toString().replaceFirst('Exception: ', ''),
        action: 'Periksa halaman Inventaris dan lakukan restock terlebih dahulu.',
        category: ErrorCategory.data,
      );
    }

    // ── ObjectBox / Database Errors ──────────────────────────
    if (errorStr.contains('objectbox') || errorStr.contains('database')) {
      return const AppError(
        title: 'Gagal Menyimpan Data',
        message: 'Terjadi masalah pada database lokal perangkat.',
        action: 'Coba lagi. Jika masalah berlanjut, restart aplikasi.',
        category: ErrorCategory.storage,
      );
    }

    // ── Sync Errors ───────────────────────────────────────────
    if (errorStr.contains('sync') || errorStr.contains('firestore')) {
      return const AppError(
        title: 'Sinkronisasi Gagal',
        message: 'Data berhasil disimpan di lokal, namun gagal dikirim ke awan.',
        action: 'Data akan otomatis dikirim ulang saat koneksi tersedia.',
        category: ErrorCategory.sync,
      );
    }

    // ── Fallback: Unknown Error ───────────────────────────────
    return AppError(
      title: 'Terjadi Kesalahan',
      message: 'Kesalahan tidak terduga pada aplikasi.',
      action: 'Coba lagi atau restart aplikasi. Kode: ${error.runtimeType}',
      category: ErrorCategory.unknown,
    );
  }

  // ── Private: Firebase Auth Error Mapping ────────────────────
  static AppError _fromFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AppError(
          title: 'Akun Tidak Ditemukan',
          message: 'Email yang Anda masukkan tidak terdaftar.',
          action: 'Periksa kembali email Anda atau hubungi Owner bengkel.',
          category: ErrorCategory.auth,
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AppError(
          title: 'Kata Sandi Salah',
          message: 'Email atau kata sandi yang Anda masukkan tidak sesuai.',
          action: 'Periksa kembali email dan kata sandi Anda.',
          category: ErrorCategory.auth,
        );
      case 'email-already-in-use':
        return const AppError(
          title: 'Email Sudah Digunakan',
          message: 'Akun dengan email ini sudah terdaftar.',
          action: 'Gunakan email lain atau login dengan akun yang sudah ada.',
          category: ErrorCategory.auth,
        );
      case 'user-disabled':
        return const AppError(
          title: 'Akun Dinonaktifkan',
          message: 'Akun Anda telah dinonaktifkan oleh Owner bengkel.',
          action: 'Hubungi Owner bengkel untuk mengaktifkan kembali akun Anda.',
          category: ErrorCategory.auth,
        );
      case 'network-request-failed':
        return const AppError(
          title: 'Gagal Login',
          message: 'Tidak dapat terhubung ke server autentikasi.',
          action: 'Periksa koneksi internet Anda dan coba login kembali.',
          category: ErrorCategory.network,
        );
      case 'too-many-requests':
        return const AppError(
          title: 'Terlalu Banyak Percobaan',
          message: 'Akun sementara dikunci karena terlalu banyak percobaan login.',
          action: 'Tunggu beberapa menit, lalu coba lagi.',
          category: ErrorCategory.auth,
        );
      case 'id-token-revoked':
      case 'token_revoked':
        return const AppError(
          title: 'Sesi Tidak Valid',
          message: 'Sesi login Anda telah dicabut.',
          action: 'Login kembali untuk melanjutkan.',
          category: ErrorCategory.auth,
        );
      default:
        return AppError(
          title: 'Gagal Autentikasi',
          message: e.message ?? 'Terjadi masalah autentikasi.',
          action: 'Coba lagi. Jika masalah berlanjut, hubungi dukungan.',
          category: ErrorCategory.auth,
        );
    }
  }

  // ── Private: Firestore Error Mapping ───────────────────────
  static AppError _fromFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const AppError(
          title: 'Akses Ditolak',
          message: 'Anda tidak memiliki ijin untuk mengakses data ini.',
          action: 'Hubungi Owner bengkel untuk mengatur izin Anda.',
          category: ErrorCategory.permission,
        );
      case 'unavailable':
        return const AppError(
          title: 'Layanan Tidak Tersedia',
          message: 'Server data awan sedang tidak dapat dijangkau.',
          action: 'Data Anda aman di lokal. Sinkronisasi akan otomatis dilanjutkan.',
          category: ErrorCategory.network,
        );
      case 'resource-exhausted':
        return const AppError(
          title: 'Batas Penggunaan Tercapai',
          message: 'Kuota server sementara habis.',
          action: 'Coba lagi dalam beberapa menit.',
          category: ErrorCategory.sync,
        );
      case 'not-found':
        return const AppError(
          title: 'Data Tidak Ditemukan',
          message: 'Data yang Anda cari tidak ada atau sudah dihapus.',
          action: 'Muat ulang halaman untuk mendapatkan data terbaru.',
          category: ErrorCategory.data,
        );
      default:
        return AppError(
          title: 'Kegagalan Sinkronisasi',
          message: e.message ?? 'Gagal berkomunikasi dengan server.',
          action: 'Periksa koneksi internet dan coba lagi.',
          category: ErrorCategory.sync,
        );
    }
  }

  /// Tampilkan error sebagai log debug yang terformat
  static void log(dynamic error, {String? context, StackTrace? stack}) {
    final appError = from(error, context: context);
    appLogger.error(
      '${appError.title}: ${appError.message}',
      context: 'ERROR_${appError.category.name.toUpperCase()}',
      error: error,
      stackTrace: stack,
    );
  }
}

