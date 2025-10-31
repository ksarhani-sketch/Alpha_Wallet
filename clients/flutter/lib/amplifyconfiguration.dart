// ignore_for_file: constant_identifier_names

const amplifyconfig = r'''
{
  "UserAgent": "aws-amplify-flutter/1.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-flutter/1.0",
        "Version": "1.0",
        "CognitoUserPool": {
          "Default": {
            "PoolId": "me-south-1_fFgG6pxPx",
            "AppClientId": "39odnset34onsbp2q283vtt5pp",
            "Region": "me-south-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH"
          }
        },
        "OAuth": {
          "WebDomain": "me-south-1ffgg6pxpx.auth.me-south-1.amazoncognito.com",
          "AppClientId": "39odnset34onsbp2q283vtt5pp",
          "SignInRedirectURI": "https://d305my1jjb07x5.cloudfront.net/",
          "SignOutRedirectURI": "https://d305my1jjb07x5.cloudfront.net/",
          "Scopes": ["openid", "email", "profile"],
          "ResponseType": "code"
        }
      }
    }
  }
}
''';
