/// Application-wide constants for Smart Greenhouse.
class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────
  static const String appName = 'Smart Greenhouse';
  static const String appVersion = '0.1.0';

  // ── API / Mock Data ──────────────────────────
  // Placeholder for future API endpoints
  static const String baseUrl = '';

  // ── Sensor Thresholds ────────────────────────
  static const double temperatureMin = 18.0;
  static const double temperatureMax = 35.0;
  static const double humidityMin = 40.0;
  static const double humidityMax = 80.0;
  static const double soilMoistureMin = 30.0;
  static const double soilMoistureMax = 70.0;
  static const double lightIntensityMin = 200.0;
  static const double lightIntensityMax = 1000.0;

  // ── UI Constants ─────────────────────────────
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double cardElevation = 2.0;
}
