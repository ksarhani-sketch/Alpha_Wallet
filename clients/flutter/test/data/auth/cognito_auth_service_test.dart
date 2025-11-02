import 'dart:collection';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alphawallet/data/auth/amplify_config_loader.dart';
import 'package:alphawallet/data/auth/cognito_auth_service.dart';

void main() {
  group('CognitoAuthService.ensureConfigured', () {
    test('allows retry after configuration failure', () async {
      final loader = _StubAmplifyConfigLoader(
        Queue.of(<String?>['', _validConfig]),
      );
      final amplify = _FakeAmplify();
      final service = CognitoAuthService(
        authPlugin: AmplifyAuthCognito(),
        amplify: amplify,
        configLoader: loader,
      );

      await expectLater(
        service.ensureConfigured(),
        throwsA(isA<AmplifyConfigValidationException>()),
      );

      expect(amplify.configureCalls, 0);
      expect(amplify.pluginAdded, isTrue);

      await service.ensureConfigured();

      expect(amplify.configureCalls, 1);
      expect(amplify.isConfigured, isTrue);
    });
  });
}

class _StubAmplifyConfigLoader extends AmplifyConfigLoader {
  _StubAmplifyConfigLoader(this._responses);

  final Queue<String?> _responses;

  @override
  Future<String?> load() async {
    if (_responses.isEmpty) {
      return null;
    }
    return _responses.removeFirst();
  }
}

class _FakeAmplify extends Fake implements AmplifyClass {
  bool pluginAdded = false;
  bool _configured = false;
  int configureCalls = 0;

  @override
  bool get isConfigured => _configured;

  @override
  Future<void> addPlugin(dynamic plugin) async {
    pluginAdded = true;
  }

  @override
  Future<void> configure(String configuration) async {
    configureCalls++;
    _configured = true;
  }

  @override
  Future<void> reset() async {
    _configured = false;
    pluginAdded = false;
  }
}

const _validConfig = '''
{
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "config": {
          "userPool": {
            "Default": {
              "PoolId": "us-west-2_123456789",
              "AppClientId": "1h57kf5cpq17m0eml12EXAMPLE",
              "Region": "us-west-2"
            }
          },
          "CredentialsProvider": {
            "CognitoIdentity": {
              "Default": {
                "PoolId": "us-west-2:12345678-1234-1234-1234-123456789012",
                "Region": "us-west-2"
              }
            }
          },
          "oauth": {
            "WebDomain": "example.auth.us-west-2.amazoncognito.com",
            "SignInRedirectURI": "https://example.com/sign-in",
            "SignOutRedirectURI": "https://example.com/sign-out"
          }
        }
      }
    }
  }
}
''';
