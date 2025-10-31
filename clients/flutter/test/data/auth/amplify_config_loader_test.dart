import 'package:flutter_test/flutter_test.dart';

import 'package:alphawallet/data/auth/amplify_config_loader.dart';

void main() {
  group('AmplifyConfigLoader.validate redirect URI validation', () {
    test('accepts HTTPS redirect URIs', () {
      final result = AmplifyConfigLoader.validate(_configWithRedirects(
        signInRedirectUri: 'https://example.com/sign-in',
        signOutRedirectUri: 'https://example.com/sign-out',
      ));

      expect(result.error, isNull);
      expect(result.isValid, isTrue);
    });

    test('rejects non-HTTPS sign-in redirect URIs', () {
      final result = AmplifyConfigLoader.validate(_configWithRedirects(
        signInRedirectUri: 'http://example.com/sign-in',
        signOutRedirectUri: 'https://example.com/sign-out',
      ));

      expect(result.error, contains('SignInRedirectURI must be an HTTPS URL'));
      expect(result.isValid, isFalse);
    });

    test('rejects non-HTTPS sign-out redirect URIs', () {
      final result = AmplifyConfigLoader.validate(_configWithRedirects(
        signInRedirectUri: 'https://example.com/sign-in',
        signOutRedirectUri: 'myapp://sign-out',
      ));

      expect(result.error, contains('SignOutRedirectURI must be an HTTPS URL'));
      expect(result.isValid, isFalse);
    });
  });
}

String _configWithRedirects({
  required String signInRedirectUri,
  required String signOutRedirectUri,
}) {
  return '''
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
            "SignInRedirectURI": "$signInRedirectUri",
            "SignOutRedirectURI": "$signOutRedirectUri"
          }
        }
      }
    }
  }
}
''';
}
