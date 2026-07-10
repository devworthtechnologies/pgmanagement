import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  Future<GoogleSignInAccount?> signIn() async {
    try {
      // Prevent unsupported plugin call on Windows
      if (!kIsWeb && Platform.isWindows) {
        print(
          'Google Sign-In via plugin is not available on Windows desktop.',
        );
        return null;
      }

      return await _googleSignIn.signIn();
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb && Platform.isWindows) return;

    await _googleSignIn.signOut();
  }

  GoogleSignInAccount? getCurrentUser() {
    if (!kIsWeb && Platform.isWindows) return null;

    return _googleSignIn.currentUser;
  }

  Future<bool> isSignedIn() async {
    if (!kIsWeb && Platform.isWindows) return false;

    return _googleSignIn.currentUser != null;
  }
}