import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amplify_flutter/amplify_flutter.dart';

import 'amplifyconfiguration.dart';
import 'app/app.dart';
import 'data/auth/amplify_config_loader.dart';
import 'data/auth/cognito_auth_service.dart';
import 'data/auth/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = CognitoAuthService(
    configLoader: const AmplifyConfigLoader(fallbackConfig: amplifyconfig),
  );

  try {
    await authService.ensureConfigured();
  } on AmplifyConfigValidationException catch (error, stackTrace) {
    debugPrint('main: Amplify config validation failed $error\n$stackTrace');
  } on AmplifyException catch (error, stackTrace) {
    debugPrint('main: Amplify configuration failed $error\n$stackTrace');
  } catch (error, stackTrace) {
    debugPrint('main: unexpected Amplify init error $error\n$stackTrace');
  }

  runApp(
    ProviderScope(
      overrides: [
        cognitoAuthServiceProvider.overrideWithValue(authService),
      ],
      child: const AlphaWalletApp(),
    ),
  );
}
