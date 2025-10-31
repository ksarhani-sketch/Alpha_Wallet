import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import 'amplifyconfiguration.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Amplify.logLevel = LogLevel.verbose;

  await Amplify.addPlugin(AmplifyAuthCognito());

  try {
    await Amplify.configure(amplifyconfig);
  } catch (e) {
    debugPrint('Amplify.configure error: $e');
  }

  runApp(const ProviderScope(child: AlphaWalletApp()));
}
