import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:4000/api/`.
class AppConfig {
  const AppConfig._();

  static const _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Explicit `API_BASE_URL` wins. On the web the CMS serves the app itself,
  /// so the API is `/api/` on whatever origin the page came from (local or
  /// Render) with no CORS. On Android, 10.0.2.2 is the host machine as seen
  /// from the emulator.
  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kIsWeb) return Uri.base.resolve('/api/').toString();
    return 'http://10.0.2.2:4000/api/';
  }
}
