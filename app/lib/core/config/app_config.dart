/// Build-time configuration. Override with
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:4000/api/`.
class AppConfig {
  const AppConfig._();

  /// 10.0.2.2 is the host machine as seen from the Android emulator.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/',
  );
}
