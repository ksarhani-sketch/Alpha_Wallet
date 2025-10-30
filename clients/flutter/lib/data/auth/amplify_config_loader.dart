import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;

class AmplifyConfigLoader {
  const AmplifyConfigLoader();

  static final RegExp _placeholderPattern = RegExp(r'REPLACE_WITH_[A-Z0-9_]+');

  Future<String?> load() async {
    const configFromDefine = String.fromEnvironment('AMPLIFY_CONFIG');
    if (configFromDefine.trim().isNotEmpty) {
      return configFromDefine;
    }

    try {
      final asset = await rootBundle.loadString('amplifyconfiguration.json');
      if (asset.trim().isEmpty) return null;
      return asset;
    } on FlutterError catch (error) {
      debugPrint('AmplifyConfigLoader: missing asset – ${error.message}');
      return null;
    } on PlatformException catch (error) {
      debugPrint('AmplifyConfigLoader: platform error – ${error.message}');
      return null;
    }
  }

  /// Returns a human-readable validation error if [config] looks incomplete.
  /// Otherwise returns `null` when the config appears usable.
  static String? validate(String config) {
    final trimmed = config.trim();
    if (trimmed.isEmpty) {
      return 'Amplify configuration is empty. '
          'Provide a valid amplifyconfiguration.json or pass --dart-define=AMPLIFY_CONFIG.';
    }

    if (_containsJavaScriptStyleComments(trimmed)) {
      return 'Amplify configuration contains JavaScript-style comments. '
          'Remove any // or /* */ comments so the file is valid JSON.';
    }

    final placeholders = _placeholderPattern
        .allMatches(trimmed)
        .map((match) => match.group(0)!)
        .toSet();
    if (placeholders.isNotEmpty) {
      final formatted = placeholders.map((value) => value.replaceFirst('REPLACE_WITH_', '')).join(', ');
      return 'Amplify configuration still contains placeholder values '
          'for: $formatted. Update amplifyconfiguration.json or the AMPLIFY_CONFIG define.';
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (error) {
      return 'Amplify configuration is not valid JSON: $error';
    }
    if (decoded is! Map<String, dynamic>) {
      return 'Amplify configuration must decode to a JSON object.';
    }

    final auth = decoded['auth'];
    if (auth is! Map<String, dynamic>) {
      return 'Amplify configuration is missing the "auth" section.';
    }

    final plugins = auth['plugins'];
    if (plugins is! Map<String, dynamic>) {
      return 'Amplify configuration is missing auth.plugins.';
    }

    final cognito = plugins['awsCognitoAuthPlugin'];
    if (cognito is! Map<String, dynamic>) {
      return 'Amplify configuration must include auth.plugins.awsCognitoAuthPlugin.';
    }

    final configNode = _stringKeyedMap(cognito['config']);
    if (configNode == null) {
      return 'Amplify configuration is missing auth.plugins.awsCognitoAuthPlugin.config.';
    }

    final userPoolNode = _firstNonNullMap([
      configNode['userPool'],
      configNode['UserPool'],
      configNode['CognitoUserPool'],
    ]);
    if (userPoolNode == null) {
      return 'Amplify configuration must include Cognito user pool details.';
    }

    final defaultPool = _stringKeyedMap(userPoolNode['Default']);
    if (defaultPool == null) {
      return 'Amplify configuration must include a Default user pool configuration.';
    }

    final missingFields = <String>[];
    final poolId = (defaultPool['PoolId'] as String?)?.trim() ?? '';
    if (poolId.isEmpty) missingFields.add('userPool.Default.PoolId');
    final appClientId = (defaultPool['AppClientId'] as String?)?.trim() ?? '';
    if (appClientId.isEmpty) missingFields.add('userPool.Default.AppClientId');
    final region = (defaultPool['Region'] as String?)?.trim() ?? '';
    if (region.isEmpty) missingFields.add('userPool.Default.Region');

    final authConfig = _stringKeyedMap(configNode['Auth']);
    final authDefault = _stringKeyedMap(authConfig?['Default']);
    final oauth = _firstNonNullMap([
      configNode['oauth'],
      configNode['OAuth'],
      authConfig?['OAuth'],
      authDefault?['OAuth'],
    ]);
    if (oauth != null) {
      final webDomain = (oauth['WebDomain'] as String?)?.trim() ?? '';
      if (webDomain.isEmpty) missingFields.add('oauth.WebDomain');
      final redirectUri = (oauth['SignInRedirectURI'] as String?)?.trim() ?? '';
      if (redirectUri.isEmpty) missingFields.add('oauth.SignInRedirectURI');
      final signOutRedirectUri = (oauth['SignOutRedirectURI'] as String?)?.trim() ?? '';
      if (signOutRedirectUri.isEmpty) {
        missingFields.add('oauth.SignOutRedirectURI');
      }
    } else {
      missingFields.add('oauth');
    }

    if (missingFields.isNotEmpty) {
      return 'Amplify configuration is missing required Cognito fields: '
          '${missingFields.join(', ')}.';
    }

    return null;
  }

  static Map<String, dynamic>? _stringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static Map<String, dynamic>? _firstNonNullMap(Iterable<dynamic> candidates) {
    for (final candidate in candidates) {
      final map = _stringKeyedMap(candidate);
      if (map != null) return map;
    }
    return null;
  }

  static bool _containsJavaScriptStyleComments(String source) {
    var inString = false;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final current = source[index];
      if (escaped) {
        escaped = false;
        continue;
      }

      if (current == '\\') {
        escaped = true;
        continue;
      }

      if (current == '"') {
        inString = !inString;
        continue;
      }

      if (inString) {
        continue;
      }

      if (current == '/') {
        if (index + 1 >= source.length) return false;
        final next = source[index + 1];
        if (next == '/' || next == '*') {
          return true;
        }
      }
    }
    return false;
  }
}
