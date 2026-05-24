import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════
//  Threshold Config — Konfigurasi Ambang Batas Sensor Dinamis
// ═══════════════════════════════════════════════════════════════

/// Konfigurasi ambang batas sensor untuk kontrol otomatis aktuator.
///
/// Setiap sensor memiliki nilai `min` dan `max` yang membentuk
/// dead-zone (hysteresis) untuk mencegah aktuator "berkedip"
/// saat nilai sensor berada di ambang batas.
///
/// Aturan threshold:
/// - **Soil Moisture → Pompa**: `< min` → ON, `> max` → OFF
/// - **Temperature → Humidifier**: `> max` → ON, `< min` → OFF
/// - **Light → Lampu**: `< min` → ON, `> max` → OFF
@immutable
class ThresholdConfig {
  /// Batas bawah soil moisture (%) — di bawah ini pompa ON.
  final double soilMoistureMin;

  /// Batas atas soil moisture (%) — di atas ini pompa OFF.
  final double soilMoistureMax;

  /// Batas bawah suhu (°C) — di bawah ini humidifier OFF.
  final double temperatureMin;

  /// Batas atas suhu (°C) — di atas ini humidifier ON.
  final double temperatureMax;

  /// Batas bawah cahaya (lux) — di bawah ini lampu ON.
  final double lightMin;

  /// Batas atas cahaya (lux) — di atas ini lampu OFF.
  final double lightMax;

  const ThresholdConfig({
    this.soilMoistureMin = 40.0,
    this.soilMoistureMax = 60.0,
    this.temperatureMin = 28.0,
    this.temperatureMax = 33.0,
    this.lightMin = 300.0,
    this.lightMax = 20000.0,
  });

  ThresholdConfig copyWith({
    double? soilMoistureMin,
    double? soilMoistureMax,
    double? temperatureMin,
    double? temperatureMax,
    double? lightMin,
    double? lightMax,
  }) {
    return ThresholdConfig(
      soilMoistureMin: soilMoistureMin ?? this.soilMoistureMin,
      soilMoistureMax: soilMoistureMax ?? this.soilMoistureMax,
      temperatureMin: temperatureMin ?? this.temperatureMin,
      temperatureMax: temperatureMax ?? this.temperatureMax,
      lightMin: lightMin ?? this.lightMin,
      lightMax: lightMax ?? this.lightMax,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThresholdConfig &&
        other.soilMoistureMin == soilMoistureMin &&
        other.soilMoistureMax == soilMoistureMax &&
        other.temperatureMin == temperatureMin &&
        other.temperatureMax == temperatureMax &&
        other.lightMin == lightMin &&
        other.lightMax == lightMax;
  }

  @override
  int get hashCode => Object.hash(
        soilMoistureMin,
        soilMoistureMax,
        temperatureMin,
        temperatureMax,
        lightMin,
        lightMax,
      );
}

// ═══════════════════════════════════════════════════════════════
//  Threshold Notifier
// ═══════════════════════════════════════════════════════════════

/// [ThresholdNotifier] mengelola konfigurasi threshold dinamis.
///
/// Menyediakan fungsi update per-sensor dan reset ke default.
class ThresholdNotifier extends Notifier<ThresholdConfig> {
  /// Referensi ke node `/greenhouse/threshold` di RTDB.
  final DatabaseReference _thresholdRef =
      FirebaseDatabase.instance.ref('greenhouse/threshold');

  @override
  ThresholdConfig build() => const ThresholdConfig();

  /// Update threshold soil moisture.
  void updateSoilMoisture({double? min, double? max}) {
    state = state.copyWith(soilMoistureMin: min, soilMoistureMax: max);
    _syncToFirebase();
  }

  /// Update threshold temperature.
  void updateTemperature({double? min, double? max}) {
    state = state.copyWith(temperatureMin: min, temperatureMax: max);
    _syncToFirebase();
  }

  /// Update threshold light.
  void updateLight({double? min, double? max}) {
    state = state.copyWith(lightMin: min, lightMax: max);
    _syncToFirebase();
  }

  /// Reset semua threshold ke nilai default.
  void resetToDefaults() {
    state = const ThresholdConfig();
    _syncToFirebase();
  }

  // ── Cloud Sync ──────────────────────────────────────────────

  /// Sinkronisasi state threshold saat ini ke Firebase RTDB.
  ///
  /// Key JSON disesuaikan dengan kontrak data ESP32:
  /// `minTemperature`, `maxTemperature`, `minSoilMoisture`,
  /// `maxSoilMoisture`, `minLight`, `maxLight`.
  void _syncToFirebase() {
    _thresholdRef.update({
      'minTemperature': state.temperatureMin,
      'maxTemperature': state.temperatureMax,
      'minSoilMoisture': state.soilMoistureMin,
      'maxSoilMoisture': state.soilMoistureMax,
      'minLight': state.lightMin,
      'maxLight': state.lightMax,
    }).catchError((e) {
      debugPrint('[ThresholdNotifier] Sync to Firebase failed: $e');
    });
  }
}

// ═══════════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════════

/// Provider global untuk konfigurasi threshold sensor.
///
/// Contoh penggunaan:
/// ```dart
/// final config = ref.watch(thresholdProvider);
/// ref.read(thresholdProvider.notifier).updateSoilMoisture(min: 35, max: 55);
/// ```
final thresholdProvider =
    NotifierProvider<ThresholdNotifier, ThresholdConfig>(
  ThresholdNotifier.new,
);
