// google_desktop_auth_service.dart

import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleDesktopAuthService {
  static const String clientId =
      '';

  // Use your current debug secret
  static const String clientSecret =
      '';

  Future<AuthClient?> signIn() async {
    try {
      final credentials = ClientId(
        clientId,
        clientSecret,
      );

      final scopes = [
        'email',
        'profile',
        'https://www.googleapis.com/auth/drive.file',
      ];

      final client = await clientViaUserConsent(
        credentials,
        scopes,
        (url) async {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        },
      );

      print("Desktop sign-in successful");
      return client;

    } catch (e, stackTrace) {
      print("Desktop sign-in error:");
      print(e);
      print(stackTrace);
      return null;
    }
  }
}