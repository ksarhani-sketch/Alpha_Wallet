import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class AmplifyConfigLoader {
  const AmplifyConfigLoader();

  Future<String?> load() async {
    // 1) prefer --dart-define (used in CodeBuild / Web)
    const configFromDefine = String.fromEnvironment('AMPLIFY_CONFIG');
    if (configFromDefine.trim().isNotEmpty) {
      return configFromDefine;
    }

    // 2) fallback to asset file
    try {
      final asset = await rootBundle.loadString('amplifyconfiguration.json');
      if (asset.trim().isEmpty) {
        return null;
      }
      return asset;
    } on PlatformException catch (error) {
      debugPrint('AmplifyConfigLoader: missing asset: ${error.message}');
      return null;
    } on FlutterError catch (error) {
      debugPrint('AmplifyConfigLoader: flutter error: ${error.message}');
      return null;
    }
  }
}
