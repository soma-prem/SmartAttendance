import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'classroom_auth_service.dart';

class GoogleAuthHeadersClient extends http.BaseClient {
  GoogleAuthHeadersClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class DriveUploadResult {
  final String fileId;
  final String fileName;
  final String mimeType;
  final String webViewLink;

  const DriveUploadResult({
    required this.fileId,
    required this.fileName,
    required this.mimeType,
    required this.webViewLink,
  });
}

class DriveUploadService {
  final ClassroomAuthService _auth;
  DriveUploadService(this._auth);

  Future<DriveUploadResult> uploadToMyDrive({
    required File file,
    required String registeredEmail,
    List<String> shareWithEmails = const [],
  }) async {
    final account = await _auth.ensureGoogleAccount();
    if (account == null) {
      throw Exception('Google sign in cancelled.');
    }

    if (account.email.toLowerCase() != registeredEmail.toLowerCase()) {
      throw Exception(
        'Please sign in with the same email used in this app: $registeredEmail',
      );
    }

    final authHeaders = await account.authHeaders;
    final client = GoogleAuthHeadersClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    final length = await file.length();
    final media = drive.Media(file.openRead(), length);
    final driveFile = drive.File()..name = file.path.split(Platform.pathSeparator).last;

    final uploaded = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
      $fields: 'id,name,mimeType,webViewLink',
    );

    final uploadedFileId = uploaded.id;
    if (uploadedFileId == null || uploadedFileId.isEmpty) {
      throw Exception('Drive upload succeeded but file id is missing.');
    }

    for (final email in shareWithEmails) {
      final trimmed = email.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == registeredEmail.toLowerCase()) {
        continue;
      }
      final permission = drive.Permission()
        ..type = 'user'
        ..role = 'reader'
        ..emailAddress = trimmed;
      await driveApi.permissions.create(
        permission,
        uploadedFileId,
        sendNotificationEmail: false,
      );
    }

    return DriveUploadResult(
      fileId: uploadedFileId,
      fileName: uploaded.name ?? driveFile.name ?? 'file',
      mimeType: uploaded.mimeType ?? 'file',
      webViewLink: uploaded.webViewLink ?? '',
    );
  }

  Future<DriveUploadResult> uploadPublicMaterial({
    required File file,
    required String registeredEmail,
  }) async {
    final result = await uploadToMyDrive(
      file: file,
      registeredEmail: registeredEmail,
      shareWithEmails: const [],
    );

    final account = _auth.currentGoogleAccount ?? await _auth.ensureGoogleAccount();
    if (account == null) {
      throw Exception('Google sign in cancelled.');
    }
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthHeadersClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    // Make accessible to anyone with the link.
    final permission = drive.Permission()
      ..type = 'anyone'
      ..role = 'reader';
    await driveApi.permissions.create(
      permission,
      result.fileId,
      sendNotificationEmail: false,
    );

    return result;
  }
}
