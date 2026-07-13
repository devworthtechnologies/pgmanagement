// login_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:pg_management/services/google_signin_service.dart';
import 'package:pg_management/services/google_desktop_auth_service.dart';
import 'package:pg_management/screens/setup_wizard_screen.dart';
import 'package:pg_management/widgets/loading_indicator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    bool success = false;

    try {
      // Windows desktop authentication
      if (!kIsWeb && Platform.isWindows) {
        final desktopAuth = GoogleDesktopAuthService();

        final client = await desktopAuth.signIn();

        success = client != null;
      }

      // Android / iOS / Web authentication
      else {
        final account = await GoogleSignInService().signIn();

        success = account != null;
      }
    } catch (e) {
      print("Login error: $e");
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const SetupWizardScreen(),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Sign-In failed. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.house,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'PG Management',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage your PG business',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (_isLoading)
              const LoadingIndicator(
                message: 'Signing in...',
              )
            else
              ElevatedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const Icon(
                  Icons.login,
                ),
                label: const Text(
                  'Sign in with Google',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
