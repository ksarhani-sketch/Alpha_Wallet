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

  /// Performs validation and comment stripping on [config]. The returned
  /// [AmplifyConfigValidationResult] contains the sanitized JSON alongside any
  /// warnings or fatal validation errors.
  static AmplifyConfigValidationResult validate(String config) {
    final sanitized = _stripJavaScriptStyleComments(config);
    final trimmed = sanitized.sanitized.trim();
    final warnings = <String>[];

    if (sanitized.hadComments) {
      warnings.add(
        'Amplify configuration contained JavaScript-style comments. They were removed before parsing. '
        'Update amplifyconfiguration.json or the AMPLIFY_CONFIG define so the source is valid JSON.',
      );
    }

    if (trimmed.isEmpty) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error:
            'Amplify configuration is empty. Provide a valid amplifyconfiguration.json or pass --dart-define=AMPLIFY_CONFIG.',
      );
    }

    final placeholders = _placeholderPattern
        .allMatches(trimmed)
        .map((match) => match.group(0)!)
        .toSet();
    if (placeholders.isNotEmpty) {
      final formatted = placeholders.map((value) => value.replaceFirst('REPLACE_WITH_', '')).join(', ');
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error:
            'Amplify configuration still contains placeholder values for: $formatted. Update amplifyconfiguration.json or the AMPLIFY_CONFIG define.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (error) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration is not valid JSON: $error',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration must decode to a JSON object.',
      );
    }

    final auth = decoded['auth'];
    if (auth is! Map<String, dynamic>) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration is missing the "auth" section.',
      );
    }

    final plugins = auth['plugins'];
    if (plugins is! Map<String, dynamic>) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration is missing auth.plugins.',
      );
    }

    final cognito = plugins['awsCognitoAuthPlugin'];
    if (cognito is! Map<String, dynamic>) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration must include auth.plugins.awsCognitoAuthPlugin.',
      );
    }

    final configNode = _stringKeyedMap(cognito['config']);
    if (configNode == null) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration is missing auth.plugins.awsCognitoAuthPlugin.config.',
      );
    }

    final userPoolNode = _firstNonNullMap([
      configNode['userPool'],
      configNode['UserPool'],
      configNode['CognitoUserPool'],
    ]);
    if (userPoolNode == null) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration must include Cognito user pool details.',
      );
    }

    final defaultPool = _stringKeyedMap(userPoolNode['Default']);
    if (defaultPool == null) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error: 'Amplify configuration must include a Default user pool configuration.',
      );
    }

    final missingFields = <String>[];
    final poolId = (defaultPool['PoolId'] as String?)?.trim() ?? '';
    if (poolId.isEmpty) missingFields.add('userPool.Default.PoolId');
    final appClientId = (defaultPool['AppClientId'] as String?)?.trim() ?? '';
    if (appClientId.isEmpty) missingFields.add('userPool.Default.AppClientId');
    final region = (defaultPool['Region'] as String?)?.trim() ?? '';
    if (region.isEmpty) missingFields.add('userPool.Default.Region');

    final credentialsProvider = _stringKeyedMap(configNode['CredentialsProvider']);
    final cognitoIdentity = _stringKeyedMap(credentialsProvider?['CognitoIdentity']);
    final identityDefault = _stringKeyedMap(cognitoIdentity?['Default']);
    final identityPoolId = (identityDefault?['PoolId'] as String?)?.trim() ?? '';
    if (identityPoolId.isEmpty) {
      missingFields.add('CredentialsProvider.CognitoIdentity.Default.PoolId');
    }
    final identityRegion = (identityDefault?['Region'] as String?)?.trim() ?? '';
    if (identityRegion.isEmpty) {
      missingFields.add('CredentialsProvider.CognitoIdentity.Default.Region');
    }

    final authConfig = _stringKeyedMap(configNode['Auth']);
    final authDefault = _stringKeyedMap(authConfig?['Default']);
    final oauth = _firstNonNullMap([
      configNode['oauth'],
      configNode['OAuth'],
      authConfig?['OAuth'],
      authDefault?['OAuth'],
    ]);
    String webDomain = '';
    String redirectUri = '';
    String signOutRedirectUri = '';
    if (oauth != null) {
      webDomain = (oauth['WebDomain'] as String?)?.trim() ?? '';
      if (webDomain.isEmpty) missingFields.add('oauth.WebDomain');
      redirectUri = (oauth['SignInRedirectURI'] as String?)?.trim() ?? '';
      if (redirectUri.isEmpty) missingFields.add('oauth.SignInRedirectURI');
      signOutRedirectUri = (oauth['SignOutRedirectURI'] as String?)?.trim() ?? '';
      if (signOutRedirectUri.isEmpty) {
        missingFields.add('oauth.SignOutRedirectURI');
      }
      if (redirectUri.isNotEmpty) {
        final parsedRedirectUri = Uri.tryParse(redirectUri);
        if (parsedRedirectUri == null ||
            !parsedRedirectUri.hasScheme ||
            parsedRedirectUri.scheme.toLowerCase() != 'https' ||
            !parsedRedirectUri.hasAuthority) {
          return AmplifyConfigValidationResult(
            config: trimmed,
            warnings: warnings,
            error:
                'Amplify configuration SignInRedirectURI must be an HTTPS URL. Custom URI schemes are reserved for native builds.',
          );
        }
      }
      if (signOutRedirectUri.isNotEmpty) {
        final parsedSignOutRedirectUri = Uri.tryParse(signOutRedirectUri);
        if (parsedSignOutRedirectUri == null ||
            !parsedSignOutRedirectUri.hasScheme ||
            parsedSignOutRedirectUri.scheme.toLowerCase() != 'https' ||
            !parsedSignOutRedirectUri.hasAuthority) {
          return AmplifyConfigValidationResult(
            config: trimmed,
            warnings: warnings,
            error:
                'Amplify configuration SignOutRedirectURI must be an HTTPS URL. Custom URI schemes are reserved for native builds.',
          );
        }
      }
    } else {
      missingFields.add('oauth');
    }

    if (missingFields.isNotEmpty) {
      return AmplifyConfigValidationResult(
        config: trimmed,
        warnings: warnings,
        error:
            'Amplify configuration is missing required Cognito fields: ${missingFields.join(', ')}. '
            'Confirm the Cognito resources exist in AWS (user pool, app client, hosted UI domain, and identity pool) and regenerate amplifyconfiguration.json.',
      );
    }

    warnings.addAll(_awsSetupRecommendations(
      poolId: poolId,
      appClientId: appClientId,
      region: region,
      identityPoolId: identityPoolId,
      identityRegion: identityRegion,
      webDomain: webDomain,
      redirectUri: redirectUri,
      signOutRedirectUri: signOutRedirectUri,
    ));

    return AmplifyConfigValidationResult(
      config: trimmed,
      warnings: warnings,
    );
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

  static _CommentStrippingResult _stripJavaScriptStyleComments(String source) {
    final buffer = StringBuffer();
    var hadComments = false;
    var inString = false;
    var escaped = false;
    var inLineComment = false;
    var inBlockComment = false;
    var index = 0;

    while (index < source.length) {
      final char = source[index];

      if (inLineComment) {
        if (char == '\r' || char == '\n') {
          inLineComment = false;
          buffer.write(char);
          if (char == '\r' && index + 1 < source.length && source[index + 1] == '\n') {
            buffer.write('\n');
            index++;
          }
        }
        index++;
        continue;
      }

      if (inBlockComment) {
        if (char == '*' && index + 1 < source.length && source[index + 1] == '/') {
          inBlockComment = false;
          index += 2;
        } else {
          index++;
        }
        continue;
      }

      if (inString) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        index++;
        continue;
      }

      if (char == '"') {
        buffer.write(char);
        inString = true;
        index++;
        continue;
      }

      if (char == '/' && index + 1 < source.length) {
        final next = source[index + 1];
        if (next == '/') {
          hadComments = true;
          inLineComment = true;
          index += 2;
          continue;
        }
        if (next == '*') {
          hadComments = true;
          inBlockComment = true;
          index += 2;
          continue;
        }
      }

      buffer.write(char);
      index++;
    }

    return _CommentStrippingResult(
      sanitized: buffer.toString(),
      hadComments: hadComments,
    );
  }

  static List<String> _awsSetupRecommendations({
    required String poolId,
    required String appClientId,
    required String region,
    required String identityPoolId,
    required String identityRegion,
    required String webDomain,
    required String redirectUri,
    required String signOutRedirectUri,
  }) {
    final recommendations = <String>[];
    recommendations.add(
      'AWS setup check: Confirm that the Cognito user pool $poolId exists in $region and has an app client with ID $appClientId.',
    );
    if (identityPoolId.isNotEmpty) {
      recommendations.add(
        'AWS setup check: Ensure the Cognito Identity Pool $identityPoolId exists in $identityRegion and is linked to the user pool.',
      );
    }
    if (webDomain.isNotEmpty) {
      recommendations.add(
        'AWS setup check: Verify that the hosted UI domain $webDomain is active and mapped to the user pool in the AWS console.',
      );
    }
    if (redirectUri.isNotEmpty) {
      recommendations.add(
        'AWS setup check: Confirm that $redirectUri is listed as an allowed callback/redirect URL on the Cognito app client.',
      );
    }
    if (signOutRedirectUri.isNotEmpty) {
      recommendations.add(
        'AWS setup check: Confirm that $signOutRedirectUri is configured as a sign-out URL on the Cognito app client.',
      );
    }
    return recommendations;
  }
}

class AmplifyConfigValidationResult {
  const AmplifyConfigValidationResult({
    required this.config,
    this.warnings = const <String>[],
    this.error,
  });

  final String config;
  final List<String> warnings;
  final String? error;

  bool get isValid => error == null;
}

class _CommentStrippingResult {
  const _CommentStrippingResult({
    required this.sanitized,
    required this.hadComments,
  });

  final String sanitized;
  final bool hadComments;
}
