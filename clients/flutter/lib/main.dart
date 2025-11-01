import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_core/amplify_core.dart'; // <- for LogLevel / setLogLevel

import 'amplifyconfiguration.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Amplify v2: use setLogLevel instead of the removed Amplify.logLevel setter
  Amplify.setLogLevel(LogLevel.verbose);

  // No generic type arg needed in v2
  await Amplify.addPlugin(AmplifyAuthCognito());

  try {
    await Amplify.configure(amplifyconfig);
  } catch (e) {
    debugPrint('Amplify.configure error: $e');
  }

  runApp(const ProviderScope(child: AlphaWalletApp()));
}
