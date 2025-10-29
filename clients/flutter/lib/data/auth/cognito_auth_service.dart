import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

import 'amplify_config_loader.dart';

class CognitoAuthService {
  CognitoAuthService({AmplifyAuthCognito? authPlugin, AmplifyClass? amplify})
      : _amplify = amplify ?? Amplify,
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
        await _amplify.addPlugin<AmplifyAuthPluginInterface>(_authPlugin);
        _pluginAdded = true;
      }
    } on AmplifyAlreadyConfiguredException {
      _pluginAdded = true;
    }

    if (_amplify.isConfigured) {
      return;
    }

    final config = await _configLoader.load();
    if (config == null || config.trim().isEmpty) {
      throw const AmplifyException(
        'Amplify configuration is missing',
        recoverySuggestion:
            'Provide amplifyconfiguration.json or pass --dart-define=AMPLIFY_CONFIG with the Cognito config JSON.',
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
      throw const AmplifyException(
        'Expected a CognitoAuthSession but received a different session type.',
      );
    }
    return session;
  }

  Future<bool> isSignedIn() async {
    try {
      final session = await _fetchSession();
      return session.isSignedIn;
    } on SignedOutException {
      return false;
    } on InvalidStateException {
      return false;
    }
  }

  Future<void> signIn() async {
    await ensureConfigured();
    if (await isSignedIn()) {
      return;
    }
    await Amplify.Auth.signInWithWebUI();
  }

  Future<void> signOut() async {
    await ensureConfigured();
    try {
      await Amplify.Auth.signOut();
    } on SignedOutException {
      // already signed out
    }
  }

  Future<String?> getLatestIdToken({bool forceRefresh = false}) async {
    try {
      final session = await _fetchSession(forceRefresh: forceRefresh);
      if (!session.isSignedIn) {
        return null;
      }
      final tokens = session.userPoolTokens;
      if (tokens == null) {
        return null;
      }
      return tokens.idToken;
    } on SignedOutException {
      return null;
    } on InvalidStateException catch (error, stackTrace) {
      debugPrint('CognitoAuthService: invalid state while fetching token: $error\n$stackTrace');
      return null;
    }
  }

  Future<AuthUser?> currentUser() async {
    await ensureConfigured();
    try {
      return await Amplify.Auth.getCurrentUser();
    } on SignedOutException {
      return null;
    }
  }
}
