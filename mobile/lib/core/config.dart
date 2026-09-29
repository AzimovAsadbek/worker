/// Build-time configuration (pass with --dart-define).
///
///   flutter run --dart-define=API_BASE_URL=https://api.example.uz/api/v1
///
/// Default points to the host machine from the Android emulator.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');
  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);
}
