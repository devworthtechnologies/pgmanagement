import 'dart:io';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/database/database_helper.dart';

class BackupService {
  Future<drive.DriveApi> _getDriveApi() async {
    final googleSignIn = GoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('User not signed in');
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  Future<String> _getBackupFolderId(drive.DriveApi driveApi) async {
    final folderList = await driveApi.files.list(
      q: "name='${AppConstants.backupFolder}' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      $fields: 'files(id)',
    );
    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }
    final folder = drive.File()
      ..name = AppConstants.backupFolder
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await driveApi.files.create(folder);
    return created.id!;
  }

  Future<bool> backupDatabase() async {
    try {
      final driveApi = await _getDriveApi();
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return false;

      final folderId = await _getBackupFolderId(driveApi);
      final fileName = AppUtils.getBackupFileName();
      final file = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());
      await driveApi.files.create(file, uploadMedia: media);

      await _cleanupOldBackups(driveApi, folderId);
      return true;
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  Future<void> _cleanupOldBackups(drive.DriveApi driveApi, String folderId) async {
    final backupList = await driveApi.files.list(
      q: "'$folderId' in parents and mimeType != 'application/vnd.google-apps.folder' and trashed=false",
      orderBy: 'createdTime desc',
      pageSize: 10,
    );
    final files = backupList.files;
    if (files != null && files.length > 5) {
      for (int i = 5; i < files.length; i++) {
        await driveApi.files.delete(files[i].id!);
      }
    }
  }

  Future<bool> restoreBackup() async {
    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getBackupFolderId(driveApi);
      final backups = await driveApi.files.list(
        q: "'$folderId' in parents and mimeType != 'application/vnd.google-apps.folder' and trashed=false",
        orderBy: 'createdTime desc',
        pageSize: 1,
      );
      if (backups.files == null || backups.files!.isEmpty) return false;

      final latest = backups.files!.first;
      final response = await driveApi.files.get(latest.id!, downloadOptions: drive.DownloadOptions.fullMedia);
      final data = await (response as drive.Media).stream.first;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${latest.name}');
      await tempFile.writeAsBytes(data as Uint8List);

      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      await tempFile.copy(dbPath);
      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }

  Future<bool> checkBackupExists() async {
    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getBackupFolderId(driveApi);
      final backups = await driveApi.files.list(
        q: "'$folderId' in parents and trashed=false",
        pageSize: 1,
      );
      return backups.files != null && backups.files!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}