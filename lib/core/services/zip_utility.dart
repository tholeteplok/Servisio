import 'dart:convert';
import 'dart:io';
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

  /// Validates ZIP archive structure before extraction
  /// Throws exception if archive is invalid or corrupted
  static Future<void> _validateArchive(Archive archive) async {
    // Check for required files
    final fileNames = archive.files.map((f) => f.name).toSet();

    for (final requiredFile in _requiredFiles) {
      if (!fileNames.contains(requiredFile)) {
        throw Exception('Backup corrupt: Missing required file "$requiredFile"');
      }
    }

    // Check for at least one required directory
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

    // Check for file corruption (try to read settings.json)
    try {
      final settingsFile = archive.files.firstWhere(
        (f) => f.name == 'settings.json',
        orElse: () => throw Exception('settings.json not found'),
      );
      final content = utf8.decode(settingsFile.content as List<int>);
      jsonDecode(content); // Will throw if invalid JSON
    } catch (e) {
      throw Exception('Backup corrupt: settings.json is invalid - $e');
    }

    appLogger.info('ZIP archive validation passed', context: 'ZipUtility');
  }

  /// Extracts a ZIP archive and overwrites local data.
  /// Validates archive structure before extraction.
  static Future<void> extractRestoreZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final zipDecoder = ZipDecoder();
    final archive = zipDecoder.decodeBytes(bytes);

    // ✅ VALIDATION: Check archive structure before extraction
    await _validateArchive(archive);

    final appDocDir = await getApplicationDocumentsDirectory();

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;

        if (filename == 'settings.json') {
          // Special handling for settings to ensure Cross-Platform Compatibility
          final jsonStr = utf8.decode(data);
          await SettingsBackupService.importFromJson(jsonStr);
        } else {
          // General files (Media, ObjectBox)
          final outFile = File(p.join(appDocDir.path, filename));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        }
      }
    }
    appLogger.info('Backup restore completed successfully', context: 'ZipUtility');
  }
}


