import 'package:flutter/foundation.dart';

/// Representasi data sensor dari perangkat ESP32 di greenhouse.
///
/// Setiap instance merepresentasikan satu snapshot pembacaan sensor
/// pada waktu tertentu ([timestamp]).
@immutable
class SensorData {
  /// Suhu udara dalam derajat Celsius (°C).
  final double temperature;

  /// Kelembaban udara relatif dalam persen (%).
  final double humidity;

  /// Kelembaban tanah dalam persen (%).
  final double soilMoisture;

  /// Intensitas cahaya dalam satuan lux.
  final double lightIntensity;

  /// Waktu pembacaan sensor.
  final DateTime timestamp;

  const SensorData({
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.lightIntensity,
    required this.timestamp,
  });

  /// Membuat salinan [SensorData] dengan nilai yang diperbarui.
  SensorData copyWith({
    double? temperature,
    double? humidity,
    double? soilMoisture,
    double? lightIntensity,
    DateTime? timestamp,
  }) {
    return SensorData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorData &&
        other.temperature == temperature &&
        other.humidity == humidity &&
        other.soilMoisture == soilMoisture &&
        other.lightIntensity == lightIntensity &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      temperature,
      humidity,
      soilMoisture,
      lightIntensity,
      timestamp,
    );
  }

  @override
  String toString() {
    return 'SensorData('
        'temperature: ${temperature.toStringAsFixed(1)}°C, '
        'humidity: ${humidity.toStringAsFixed(1)}%, '
        'soilMoisture: ${soilMoisture.toStringAsFixed(1)}%, '
        'lightIntensity: ${lightIntensity.toStringAsFixed(0)} lux, '
        'timestamp: $timestamp)';
  }
}

// ═══════════════════════════════════════════════════════════════
//  Telemetry Data — Unified Sensor + Actuator (Single Source of Truth)
// ═══════════════════════════════════════════════════════════════

/// Representasi data telemetri lengkap dari ESP32.
///
/// Menggabungkan pembacaan sensor dan status aktuator dalam satu
/// objek, menjadikan ESP32 sebagai Single Source of Truth.
/// UI membaca state dari objek ini; perintah manual dikirim via
/// [TelemetryNotifier.sendManualCommand].
@immutable
class TelemetryData {
  // ── Sensor readings ──────────────────────────────────────

  /// Suhu udara dalam derajat Celsius (°C).
  final double temperature;

  /// Kelembaban udara relatif dalam persen (%).
  final double humidity;

  /// Kelembaban tanah dalam persen (%).
  final double soilMoisture;

  /// Intensitas cahaya dalam satuan lux.
  final double lightIntensity;

  /// Waktu pembacaan telemetri.
  final DateTime timestamp;

  // ── Actuator states (ditentukan oleh ESP32) ──────────────

  /// Status pompa air — `true` jika menyala.
  final bool isPumpOn;

  /// Status humidifier — `true` jika menyala.
  final bool isHumidifierOn;

  /// Status lampu grow-light — `true` jika menyala.
  final bool isLightOn;

  // ── Manual override flags ────────────────────────────────

  /// Apakah pompa sedang dalam mode manual override.
  final bool isPumpManual;

  /// Apakah humidifier sedang dalam mode manual override.
  final bool isHumidifierManual;

  /// Apakah lampu sedang dalam mode manual override.
  final bool isLightManual;

  const TelemetryData({
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.lightIntensity,
    required this.timestamp,
    this.isPumpOn = false,
    this.isHumidifierOn = false,
    this.isLightOn = false,
    this.isPumpManual = false,
    this.isHumidifierManual = false,
    this.isLightManual = false,
  });

  /// Konversi ke [SensorData] untuk backward compatibility (chart).
  SensorData toSensorData() {
    return SensorData(
      temperature: temperature,
      humidity: humidity,
      soilMoisture: soilMoisture,
      lightIntensity: lightIntensity,
      timestamp: timestamp,
    );
  }

  /// Apakah ada aktuator dalam mode manual override.
  bool get hasManualOverride =>
      isPumpManual || isHumidifierManual || isLightManual;

  /// Membuat salinan [TelemetryData] dengan nilai yang diperbarui.
  TelemetryData copyWith({
    double? temperature,
    double? humidity,
    double? soilMoisture,
    double? lightIntensity,
    DateTime? timestamp,
    bool? isPumpOn,
    bool? isHumidifierOn,
    bool? isLightOn,
    bool? isPumpManual,
    bool? isHumidifierManual,
    bool? isLightManual,
  }) {
    return TelemetryData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      timestamp: timestamp ?? this.timestamp,
      isPumpOn: isPumpOn ?? this.isPumpOn,
      isHumidifierOn: isHumidifierOn ?? this.isHumidifierOn,
      isLightOn: isLightOn ?? this.isLightOn,
      isPumpManual: isPumpManual ?? this.isPumpManual,
      isHumidifierManual: isHumidifierManual ?? this.isHumidifierManual,
      isLightManual: isLightManual ?? this.isLightManual,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TelemetryData &&
        other.temperature == temperature &&
        other.humidity == humidity &&
        other.soilMoisture == soilMoisture &&
        other.lightIntensity == lightIntensity &&
        other.timestamp == timestamp &&
        other.isPumpOn == isPumpOn &&
        other.isHumidifierOn == isHumidifierOn &&
        other.isLightOn == isLightOn &&
        other.isPumpManual == isPumpManual &&
        other.isHumidifierManual == isHumidifierManual &&
        other.isLightManual == isLightManual;
  }

  @override
  int get hashCode {
    return Object.hash(
      temperature,
      humidity,
      soilMoisture,
      lightIntensity,
      timestamp,
      isPumpOn,
      isHumidifierOn,
      isLightOn,
      isPumpManual,
      isHumidifierManual,
      isLightManual,
    );
  }

  @override
  String toString() {
    return 'TelemetryData('
        'temp: ${temperature.toStringAsFixed(1)}°C, '
        'hum: ${humidity.toStringAsFixed(1)}%, '
        'soil: ${soilMoisture.toStringAsFixed(1)}%, '
        'light: ${lightIntensity.toStringAsFixed(0)} lux, '
        'pump: ${isPumpOn ? "ON" : "OFF"}${isPumpManual ? "(M)" : ""}, '
        'humidifier: ${isHumidifierOn ? "ON" : "OFF"}${isHumidifierManual ? "(M)" : ""}, '
        'lamp: ${isLightOn ? "ON" : "OFF"}${isLightManual ? "(M)" : ""})';
  }
}
