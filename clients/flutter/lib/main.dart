import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import 'amplifyconfiguration.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add the Cognito plugin (ignore if it was already added/configured earlier)
  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
  } on AmplifyAlreadyConfiguredException {
    // Plugin already added in a previous run; ignore.
  } catch (e) {
    // If adding the plugin fails for some other reason, log and continue.
    debugPrint('Amplify.addPlugin error: $e');
  }

  // Configure Amplify (ignore if already configured)
  try {
    await Amplify.configure(amplifyconfig);
  } on AmplifyAlreadyConfiguredException {
    // Already configured; safe to proceed.
  } catch (e) {
    debugPrint('Amplify.configure error: $e');
  }

  runApp(const ProviderScope(child: AlphaWalletApp()));
}
