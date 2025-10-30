import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, PlatformException; // ← add PlatformException

class AmplifyConfigLoader {
  const AmplifyConfigLoader();

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
}
