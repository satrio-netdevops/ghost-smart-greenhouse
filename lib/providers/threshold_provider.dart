import 'dart:async';

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
/// - **Humidity → Humidifier**: `< min` → ON, `> max` → OFF
/// - **Temperature**: disimpan untuk monitoring / automation lain
/// - **Light → Lampu**: `< min` → ON, `> max` → OFF
@immutable
class ThresholdConfig {
  /// Batas bawah soil moisture (%) — di bawah ini pompa ON.
  final double soilMoistureMin;

  /// Batas atas soil moisture (%) — di atas ini pompa OFF.
  final double soilMoistureMax;

  /// Batas bawah suhu (°C) — disimpan untuk monitoring.
  final double temperatureMin;

  /// Batas atas suhu (°C) — disimpan untuk monitoring.
  final double temperatureMax;

  /// Batas bawah cahaya (lux) — di bawah ini lampu ON.
  final double lightMin;

  /// Batas atas cahaya (lux) — di atas ini lampu OFF.
  final double lightMax;

  /// Batas bawah kelembapan (RH%) — di bawah ini humidifier ON.
  final double minHumidity;

  /// Batas atas kelembapan (RH%) — di atas ini humidifier OFF.
  final double maxHumidity;

  const ThresholdConfig({
    this.soilMoistureMin = 40.0,
    this.soilMoistureMax = 60.0,
    this.temperatureMin = 28.0,
    this.temperatureMax = 33.0,
    this.lightMin = 300.0,
    this.lightMax = 20000.0,
    this.minHumidity = 60.0,
    this.maxHumidity = 80.0,
  });

  ThresholdConfig copyWith({
    double? soilMoistureMin,
    double? soilMoistureMax,
    double? temperatureMin,
    double? temperatureMax,
    double? lightMin,
    double? lightMax,
    double? minHumidity,
    double? maxHumidity,
  }) {
    return ThresholdConfig(
      soilMoistureMin: soilMoistureMin ?? this.soilMoistureMin,
      soilMoistureMax: soilMoistureMax ?? this.soilMoistureMax,
      temperatureMin: temperatureMin ?? this.temperatureMin,
      temperatureMax: temperatureMax ?? this.temperatureMax,
      lightMin: lightMin ?? this.lightMin,
      lightMax: lightMax ?? this.lightMax,
      minHumidity: minHumidity ?? this.minHumidity,
      maxHumidity: maxHumidity ?? this.maxHumidity,
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
        other.lightMax == lightMax &&
        other.minHumidity == minHumidity &&
        other.maxHumidity == maxHumidity;
  }

  @override
  int get hashCode => Object.hash(
        soilMoistureMin,
        soilMoistureMax,
        temperatureMin,
        temperatureMax,
        lightMin,
        lightMax,
        minHumidity,
        maxHumidity,
      );
}

// ═══════════════════════════════════════════════════════════════
//  Threshold Notifier
// ═══════════════════════════════════════════════════════════════

/// [ThresholdNotifier] mengelola konfigurasi threshold dinamis.
///
/// Menyediakan fungsi update per-sensor dan reset ke default.
/// Mendengarkan perubahan dari Firebase RTDB untuk sinkronisasi
/// dua arah (local → cloud dan cloud → local).
class ThresholdNotifier extends Notifier<ThresholdConfig> {
  /// Referensi ke node `/greenhouse/threshold` di RTDB.
  final DatabaseReference _thresholdRef =
      FirebaseDatabase.instance.ref('greenhouse/threshold');

  StreamSubscription<DatabaseEvent>? _firebaseSub;

  @override
  ThresholdConfig build() {
    // Dengarkan perubahan threshold dari Firebase RTDB.
    _listenToFirebase();

    // Cleanup saat provider di-dispose.
    ref.onDispose(() {
      _firebaseSub?.cancel();
    });

    return const ThresholdConfig();
  }

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

  /// Update threshold humidity (RH%) — mengontrol Humidifier.
  void updateHumidity({double? min, double? max}) {
    state = state.copyWith(minHumidity: min, maxHumidity: max);
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
  /// `maxSoilMoisture`, `minLight`, `maxLight`,
  /// `minHumidity`, `maxHumidity`.
  void _syncToFirebase() {
    _thresholdRef.update({
      'minTemperature': state.temperatureMin,
      'maxTemperature': state.temperatureMax,
      'minSoilMoisture': state.soilMoistureMin,
      'maxSoilMoisture': state.soilMoistureMax,
      'minLight': state.lightMin,
      'maxLight': state.lightMax,
      'minHumidity': state.minHumidity,
      'maxHumidity': state.maxHumidity,
    }).catchError((e) {
      debugPrint('[ThresholdNotifier] Sync to Firebase failed: $e');
    });
  }

  // ── Data Stream — Firebase Listener ─────────────────────────

  /// Mendengarkan perubahan di node `greenhouse/threshold` dari
  /// Firebase RTDB untuk sinkronisasi dua arah.
  ///
  /// Saat app pertama kali berjalan atau saat data berubah dari
  /// perangkat lain / Firebase Console, state diperbarui otomatis.
  void _listenToFirebase() {
    _firebaseSub = _thresholdRef.onValue.listen((event) {
      try {
        final data = event.snapshot.value;
        if (data == null || data is! Map) return;

        final map = Map<String, dynamic>.from(data);
        state = state.copyWith(
          soilMoistureMin:
              _parseDouble(map['minSoilMoisture'], state.soilMoistureMin),
          soilMoistureMax:
              _parseDouble(map['maxSoilMoisture'], state.soilMoistureMax),
          temperatureMin:
              _parseDouble(map['minTemperature'], state.temperatureMin),
          temperatureMax:
              _parseDouble(map['maxTemperature'], state.temperatureMax),
          lightMin: _parseDouble(map['minLight'], state.lightMin),
          lightMax: _parseDouble(map['maxLight'], state.lightMax),
          minHumidity: _parseDouble(map['minHumidity'], state.minHumidity),
          maxHumidity: _parseDouble(map['maxHumidity'], state.maxHumidity),
        );
      } catch (e) {
        debugPrint('[ThresholdNotifier] Error parsing Firebase data: $e');
      }
    }, onError: (error) {
      debugPrint('[ThresholdNotifier] Firebase listener error: $error');
    });
  }

  /// Parsing aman untuk double dari data Firebase.
  /// Mengembalikan [fallback] jika parsing gagal.
  double _parseDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
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
/// ref.read(thresholdProvider.notifier).updateHumidity(min: 55, max: 75);
/// ```
final thresholdProvider =
    NotifierProvider<ThresholdNotifier, ThresholdConfig>(
  ThresholdNotifier.new,
);
