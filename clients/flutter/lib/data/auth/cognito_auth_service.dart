import 'dart:async';

// Import the Cognito plugin with an alias for constructing the plugin instance
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' as amplify_auth_cognito;
// Bring specific Cognito classes into scope so that they can be referenced
// directly without the alias.  Without this import the types would not be
// available and the compiler would throw `Type not found` errors.
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart'
    show CognitoAuthSession, SignedOutException, InvalidStateException;
import 'package:amplify_auth_cognito_dart/amplify_auth_cognito_dart.dart'
    as amplify_auth_cognito_dart;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

import 'amplify_config_loader.dart';

/// An exception thrown when the Amplify configuration is missing or invalid.
class AmplifyConfigValidationException implements Exception {
  AmplifyConfigValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A service that encapsulates the Amplify Auth/Cognito configuration and
/// exposes helper methods for sign‑in, sign‑out, and token retrieval.  The
/// service lazily adds the appropriate Auth plugin (either the regular
/// `amplify_auth_cognito` plugin or the Dart‑only variant for web/Windows)
/// and configures Amplify on demand.  It also caches the configuration
/// future so that multiple callers can await the same initialization.
class CognitoAuthService {
  CognitoAuthService({
    AuthPluginInterface? authPlugin,
    AmplifyClass? amplify,
    AmplifyConfigLoader? configLoader,
  })  : _amplify = amplify ?? Amplify,
        _authPlugin = authPlugin,
        _pluginFactory = authPlugin != null
            ? (() => authPlugin)
            : CognitoAuthService._createDefaultPlugin,
        _usesInjectedPlugin = authPlugin != null,
        _configLoader = configLoader ?? const AmplifyConfigLoader();

  final AmplifyClass _amplify;
  AuthPluginInterface? _authPlugin;
  final AuthPluginInterface Function() _pluginFactory;
  final bool _usesInjectedPlugin;
  final AmplifyConfigLoader _configLoader;

  Future<void>? _configureFuture;
  bool _pluginAdded = false;

  /// Select the appropriate plugin implementation for the current platform.
  static AuthPluginInterface _createDefaultPlugin() {
    if (kIsWeb) {
      return amplify_auth_cognito_dart.AmplifyAuthCognitoDart();
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return amplify_auth_cognito_dart.AmplifyAuthCognitoDart();
      default:
        return amplify_auth_cognito.AmplifyAuthCognito();
    }
  }

  /// Lazily instantiate the plugin when first accessed.
  AuthPluginInterface get _plugin => _authPlugin ??= _pluginFactory();

  /// Ensure that Amplify has been configured.  Multiple calls will await the
  /// same configuration future.
  Future<void> ensureConfigured() {
    return _configureFuture ??= _configureWithRetryReset();
  }

  Future<void> _configureWithRetryReset() async {
    try {
      await _configure();
    } catch (error, stackTrace) {
      // Reset the cached future so that subsequent callers can retry
      _configureFuture = null;
      Error.throwWithStackTrace(error, stackTrace as StackTrace);
    }
  }

  /// Reset Amplify and clear any cached plugin instances.  This can be used
  /// after a failed configuration to allow a fresh attempt.
  Future<void> reset() async {
    _configureFuture = null;
    if (_pluginAdded || _amplify.isConfigured) {
      try {
        await _amplify.reset();
      } on AmplifyException catch (error, stackTrace) {
        debugPrint('CognitoAuthService: failed to reset Amplify $error\n$stackTrace');
      } finally {
        _pluginAdded = false;
      }
    }
    _resetCachedPluginInstance();
  }

  /// Perform the actual configuration: add the plugin if needed, load the
  /// configuration JSON via the loader, validate it, and call configure.
  Future<void> _configure() async {
    await _addPluginIfNeeded();
    if (_amplify.isConfigured) return;

    final config = await _configLoader.load();
    if (config == null || config.trim().isEmpty) {
      throw AmplifyConfigValidationException(
        'Amplify configuration is missing. '
        'Provide amplifyconfiguration.json or pass --dart-define=AMPLIFY_CONFIG with the Cognito config JSON.',
      );
    }

    final validation = AmplifyConfigLoader.validate(config);
    if (!validation.isValid && validation.error != null) {
      throw AmplifyConfigValidationException(validation.error!);
    }

    for (final warning in validation.warnings) {
      debugPrint('CognitoAuthService: $warning');
    }

    await _configureAmplify(validation.config);
  }

  /// Configure Amplify with retry logic for the plugin‐not‐added error.
  Future<void> _configureAmplify(String config) async {
    try {
      await _amplify.configure(config);
    } on AmplifyAlreadyConfiguredException {
      // Safe to ignore – configuration is already in place.
    } on AmplifyException catch (error, stackTrace) {
      if (_isPluginNotAddedError(error)) {
        debugPrint('CognitoAuthService: auth plugin missing during configure, retrying…');
        _pluginAdded = false;
        _resetCachedPluginInstance();
        try {
          await _addPluginIfNeeded();
        } on AmplifyException catch (addError, addStackTrace) {
          debugPrint('CognitoAuthService: retry add plugin failed $addError\n$addStackTrace');
          rethrow;
        }
        try {
          await _amplify.configure(config);
        } on AmplifyAlreadyConfiguredException {
          // Another caller beat us to configuration – safe to proceed.
        }
      } else {
        debugPrint('CognitoAuthService: configure failed $error\n$stackTrace');
        rethrow;
      }
    }
  }

  bool _isPluginAlreadyAddedError(AmplifyException error) {
    final message = error.message.toLowerCase();
    return message.contains('has already been added');
  }

  bool _isPluginNotAddedError(AmplifyException error) {
    final message = error.message.toLowerCase();
    return message.contains('has not been added');
  }

  bool _isPluginInstanceClosedError(AmplifyException error) {
    final message = error.message.toLowerCase();
    return message.contains('cannot add event after closing');
  }

  void _resetCachedPluginInstance() {
    if (_usesInjectedPlugin) {
      _authPlugin = _pluginFactory();
    } else {
      _authPlugin = null;
    }
  }

  /// Add the plugin to Amplify if it hasn’t been added yet.  Handles common
  /// transient errors by retrying with a fresh plugin instance.
  Future<void> _addPluginIfNeeded() async {
    if (_pluginAdded) return;
    try {
      await _amplify.addPlugin(_plugin);
      _pluginAdded = true;
      return;
    } on AmplifyAlreadyConfiguredException {
      _pluginAdded = true;
      return;
    } on AmplifyException catch (error, stackTrace) {
      if (_isPluginAlreadyAddedError(error)) {
        _pluginAdded = true;
        return;
      }
      if (_isPluginInstanceClosedError(error) && !_usesInjectedPlugin) {
        debugPrint('CognitoAuthService: cached plugin instance unavailable, recreating…');
        _authPlugin = null;
        try {
          await _amplify.addPlugin(_plugin);
          _pluginAdded = true;
          return;
        } on AmplifyAlreadyConfiguredException {
          _pluginAdded = true;
          return;
        } on AmplifyException catch (retryError, retryStackTrace) {
          if (_isPluginAlreadyAddedError(retryError)) {
            _pluginAdded = true;
            return;
          }
          debugPrint('CognitoAuthService: retry add plugin failed '
              '$retryError\n$retryStackTrace');
          rethrow;
        }
      }
      debugPrint('CognitoAuthService: failed to add plugin '
          '$error\n$stackTrace');
      rethrow;
    }
  }

  /// Fetch the current Cognito auth session, ensuring the plugin is configured.
  Future<CognitoAuthSession> _fetchSession({bool forceRefresh = false}) async {
    await ensureConfigured();
    final session = await Amplify.Auth.fetchAuthSession(
      options: FetchAuthSessionOptions(forceRefresh: forceRefresh),
    );
    if (session is! CognitoAuthSession) {
      throw StateError(
        'Expected a CognitoAuthSession but received a different session type.',
      );
    }
    return session;
  }

  /// Return whether a user is currently signed in.  If the session fetch fails
  /// due to the user being signed out or the state being invalid, false is
  /// returned.
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

  /// Initiate a hosted UI sign‑in.  If the user is already signed in this is
  /// a no‑op.
  Future<void> signIn() async {
    await ensureConfigured();
    if (await isSignedIn()) return;
    await Amplify.Auth.signInWithWebUI(provider: AuthProvider.cognito);
  }

  /// Sign the user out.  Any SignedOutException is silently ignored, since it
  /// simply indicates that the user was not signed in.
  Future<void> signOut() async {
    await ensureConfigured();
    try {
      await Amplify.Auth.signOut();
    } on SignedOutException {
      // already signed out
    }
  }

  /// Retrieve the latest ID token (JWT) if the user is signed in.  If the
  /// session is expired or the user is signed out, null is returned.
  Future<String?> getLatestIdToken({bool forceRefresh = false}) async {
    try {
      final session = await _fetchSession(forceRefresh: forceRefresh);
      if (!session.isSignedIn) return null;
      // Amplify Auth v2: tokens exposed via Result wrapper
      final tokens = session.userPoolTokensResult.valueOrNull;
      final jwt = tokens?.idToken;
      return jwt?.raw;
    } on SignedOutException {
      return null;
    } on InvalidStateException catch (error, stackTrace) {
      debugPrint('CognitoAuthService: invalid state while fetching token: $error\n$stackTrace');
      return null;
    }
  }

  /// Return the current signed‑in user or null if the user is signed out.
  Future<AuthUser?> currentUser() async {
    await ensureConfigured();
    try {
      return await Amplify.Auth.getCurrentUser();
    } on SignedOutException {
      return null;
    }
  }
}
