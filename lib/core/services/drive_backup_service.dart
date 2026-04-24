import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive_api;
import '../utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'auth_service.dart';
import 'zip_utility.dart';
import 'settings_backup_service.dart';

class DriveBackupService {
  static final DriveBackupService _instance = DriveBackupService._internal();
  factory DriveBackupService() => _instance;
  DriveBackupService._internal();

  final AuthService _authService = AuthService();

  static const int maxRetries = 3;
  static const Duration initialBackoff = Duration(seconds: 2);

  Future<T> _retry<T>(Future<T> Function() operation, {int retryCount = 0}) async {
    try {
      return await operation();
    } catch (e) {
      if (retryCount >= maxRetries) rethrow;

      final backoff = initialBackoff * (1 << retryCount);
      appLogger.warning('Drive operation failed, retrying in ${backoff.inSeconds}s', context: 'DriveBackupService', error: e);
      await Future.delayed(backoff);
      return _retry(operation, retryCount: retryCount + 1);
    }
  }

  /// Uploads a new backup ZIP to the hidden appDataFolder with retry.
  Future<void> uploadBackup() async {
    await _retry(() async {
      final client = await _authService.getAuthenticatedClient();
      final drive = drive_api.DriveApi(client);

      final settingsJson = await SettingsBackupService.exportToJson();
      final zipFile = await ZipUtility.createBackupZip(settingsJson);

      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'servislog_backup_v1_$timestamp.zip';

        final media = drive_api.Media(zipFile.openRead(), zipFile.lengthSync());
        final driveFile = drive_api.File()
          ..name = fileName
          ..parents = ['appDataFolder'];

        await drive.files.create(driveFile, uploadMedia: media);
      } finally {
        // Cleanup temp zip
        if (await zipFile.exists()) await zipFile.delete();
      }
    });
  }

  /// Finds and downloads the latest backup from Drive with retry.
  Future<File?> downloadLatestBackup() async {
    return await _retry(() async {
      final client = await _authService.getAuthenticatedClient();
      final drive = drive_api.DriveApi(client);

      // List files in appDataFolder, ordered by createdTime descending
      final fileList = await drive.files.list(
        q: "name contains 'servislog_backup_v1' and trashed = false",
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 1,
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return null;
      }

      final latestFile = fileList.files!.first;
      final fileId = latestFile.id!;

      final drive_api.Media media = await drive.files.get(
        fileId,
        downloadOptions: drive_api.DownloadOptions.fullMedia,
      ) as drive_api.Media;

      final tempDir = await getTemporaryDirectory();
      final destinationFile = File(
        p.join(tempDir.path, 'downloaded_backup.zip'),
      );

      final IOSink sink = destinationFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      return destinationFile;
    });
  }

  /// Checks if any backup exists in Drive.
  Future<bool> hasBackupOnDrive() async {
    return await _retry(() async {
      final client = await _authService.getAuthenticatedClient();
      final drive = drive_api.DriveApi(client);

      final fileList = await drive.files.list(
        q: "name contains 'servislog_backup_v1' and trashed = false",
        spaces: 'appDataFolder',
        pageSize: 1,
      );

      return fileList.files != null && fileList.files!.isNotEmpty;
    });
  }

  /// Deletes backup files from Drive appDataFolder with retry.
  /// If [keepLatest] is true, the most recent backup file is preserved.
  Future<void> deleteAllBackups({bool keepLatest = true}) async {
    await _retry(() async {
      final client = await _authService.getAuthenticatedClient();
      final drive = drive_api.DriveApi(client);

      // List all backup files, ordered by creation time descending
      final fileList = await drive.files.list(
        q: "name contains 'servislog_backup_v1' and trashed = false",
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
      );

      if (fileList.files == null || fileList.files!.isEmpty) return;

      var filesToDelete = fileList.files!;
      if (keepLatest && filesToDelete.isNotEmpty) {
        filesToDelete = filesToDelete.sublist(1); // Preserve the latest one
      }

      for (var file in filesToDelete) {
        if (file.id != null) {
          await drive.files.delete(file.id!);
          appLogger.info('Deleted Drive backup: ${file.name}', context: 'DriveBackupService');
        }
      }
    });
  }
}

