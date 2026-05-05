import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'settings_backup_service.dart';
import '../utils/app_logger.dart';

class ZipUtility {
  static const int maxBackupSizeBytes = 100 * 1024 * 1024; // 100MB

  /// Required files that must exist in a valid backup
  static const Set<String> _requiredFiles = {
    'settings.json',
  };

  /// Required directories that must exist in a valid backup
  static const Set<String> _requiredDirectories = {
    'objectbox',
  };

  /// Creates a ZIP archive containing settings, media, and database.
  static Future<File> createBackupZip(String settingsJson) async {
    final archive = Archive();
    final appDocDir = await getApplicationDocumentsDirectory();

    // Add settings.json
    final settingsData = utf8.encode(settingsJson);
    archive.addFile(
      ArchiveFile('settings.json', settingsData.length, settingsData),
    );

    // Directories to backup
    final directories = ['media', 'objectbox'];

    for (final dirName in directories) {
      final dir = Directory(p.join(appDocDir.path, dirName));
      if (await dir.exists()) {
        final files = dir.listSync(recursive: true);
        for (var entity in files) {
          if (entity is File) {
            final relativePath = p.relative(entity.path, from: appDocDir.path);
            final bytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          }
        }
      }
    }

    // Encode ZIP and save to temp
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) throw Exception('Gagal membuat arsip ZIP');

    // Size limit check to prevent OOM
    if (zipData.length > maxBackupSizeBytes) {
      throw Exception(
        'Ukuran backup terlalu besar (${(zipData.length / 1024 / 1024).toStringAsFixed(1)}MB). '
        'Maksimal yang diizinkan adalah ${maxBackupSizeBytes ~/ 1024 ~/ 1024}MB.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File(
      p.join(tempDir.path, 'servislog_backup_temp_$timestamp.zip'),
    );
    return await zipFile.writeAsBytes(zipData);
  }

  /// Extracts a ZIP archive and overwrites local data.
  /// Validates archive structure before extraction.
  /// ✅ Offloaded to background Isolate to prevent UI freezing.
  static Future<void> extractRestoreZip(File zipFile) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final bytes = await zipFile.readAsBytes();

    // Use compute to handle decoding and file writing in background
    await compute(_extractIsolate, {
      'bytes': bytes,
      'appDocDirPath': appDocDir.path,
    });
    
    appLogger.info('Backup restore completed successfully', context: 'ZipUtility');
  }

  /// Top-level function for compute
  static Future<void> _extractIsolate(Map<String, dynamic> params) async {
    final bytes = params['bytes'] as Uint8List;
    final appDocDirPath = params['appDocDirPath'] as String;
    
    final zipDecoder = ZipDecoder();
    final archive = zipDecoder.decodeBytes(bytes);

    // Validation
    final fileNames = archive.files.map((f) => f.name).toSet();

    for (final requiredFile in _requiredFiles) {
      if (!fileNames.contains(requiredFile)) {
        throw Exception('Backup corrupt: Missing required file "$requiredFile"');
      }
    }

    bool hasRequiredDir = false;
    for (final requiredDir in _requiredDirectories) {
      if (fileNames.any((name) => name.startsWith('$requiredDir/'))) {
        hasRequiredDir = true;
        break;
      }
    }

    if (!hasRequiredDir) {
      throw Exception('Backup corrupt: Missing required directories (objectbox/)');
    }

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;

        if (filename == 'settings.json') {
          // Special handling for settings
          final jsonStr = utf8.decode(data);
          // Note: SettingsBackupService.importFromJson might use SharedPreferences.
          // In Flutter, SharedPreferences works in background isolates as of recent versions.
          // However, if it fails, we might need to handle it differently.
          await SettingsBackupService.importFromJson(jsonStr);
        } else {
          // General files (Media, ObjectBox)
          final outFile = File(p.join(appDocDirPath, filename));
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(data);
        }
      }
    }
  }
}


