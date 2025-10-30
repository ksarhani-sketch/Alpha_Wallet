import 'dart:async';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'amplify_config_loader.dart';

class CognitoAuthService {
  CognitoAuthService({
    AmplifyAuthCognito? authPlugin,
    AmplifyClass? amplify,
  })  : _amplify = amplify ?? Amplify,
        _authPlugin = authPlugin ?? AmplifyAuthCognito();

  final AmplifyClass _amplify;
  final AmplifyAuthCognito _authPlugin;
  final AmplifyConfigLoader _configLoader = const AmplifyConfigLoader();

  Future<void>? _configureFuture;
  bool _pluginAdded = false;

  Future<void> ensureConfigured() {
    _configureFuture ??= _configure();
    return _configureFuture!;
  }

  void reset() {
    _configureFuture = null;
  }

  Future<void> _configure() async {
    try {
      if (!_pluginAdded) {
        await _amplify.addPlugin(_authPlugin);
        _pluginAdded = true;
      }
    } catch (e) {
      debugPrint("Amplify plugin already added or failed: $e");
      _pluginAdded = true;
    }

    if (_amplify.isConfigured) return;

    final config = await _configLoader.load();
    if (config == null || config.trim().isEmpty) {
      throw const AuthException(
        'Amplify configuration is missing',
        recoverySuggestion:
            'Provide amplifyconfiguration.json or pass AMPLIFY_CONFIG.',
      );
    }

    await _amplify.configure(config);
  }

  Future<CognitoAuthSession> _fetchSession({bool forceRefresh = false}) async {
    await ensureConfigured();

    final session = await Amplify.Auth.fetchAuthSession(
      options: FetchAuthSessionOptions(forceRefresh: forceRefresh),
    );

    if (session is! CognitoAuthSession) {
      throw const AuthException(
        'Expected CognitoAuthSession but got another type.',
      );
    }

    return session;
  }

  Future<bool> isSignedIn() async {
    try {
      final session = await _fetchSession();
      return session.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  Future<void> signIn() async {
    await ensureConfigured();
    if (await isSignedIn()) return;

    await Amplify.Auth.signInWithWebUI();
  }

  Future<void> signOut() async {
    await ensureConfigured();
    try {
      await Amplify.Auth.signOut();
    } catch (_) {}
  }

  Future<String?> getLatestIdToken({bool forceRefresh = false}) async {
    try {
      final session = await _fetchSession(forceRefresh: forceRefresh);
      return session.userPoolTokens?.idToken;
    } catch (err, stack) {
      debugPrint('Token fetch error: $err\n$stack');
      return null;
    }
  }

  Future<AuthUser?> currentUser() async {
    await ensureConfigured();
    try {
      return await Amplify.Auth.getCurrentUser();
    } catch (_) {
      return null;
    }
  }
}
