import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sensor_data.dart';

// ═══════════════════════════════════════════════════════════════
//  Telemetry Notifier — Firebase RTDB Real-Time Listener
// ═══════════════════════════════════════════════════════════════

/// [TelemetryNotifier] mengelola data telemetri dari ESP32 via
/// Firebase Realtime Database.
///
/// 1. Mendengarkan perubahan real-time di `/greenhouse/live`
/// 2. Menerima perintah manual override via [sendManualCommand]
///    yang menulis langsung ke RTDB
/// 3. TTL timer lokal me-reset aktuator ke mode otomatis
///
/// Firebase RTDB adalah **Single Source of Truth** — UI hanya
/// membaca state dan mengirim perintah manual via [sendManualCommand].
class TelemetryNotifier extends Notifier<TelemetryData> {
  /// Referensi ke node `/greenhouse/live` di RTDB.
  DatabaseReference get _liveRef =>
      FirebaseDatabase.instance.ref('greenhouse/live');

  /// Referensi ke node `/greenhouse/settings` di RTDB.
  DatabaseReference get _settingsRef =>
      FirebaseDatabase.instance.ref('greenhouse/settings');

  /// Referensi ke node `/greenhouse/history` di RTDB.
  DatabaseReference get _historyRef =>
      FirebaseDatabase.instance.ref('greenhouse/history');

  StreamSubscription<DatabaseEvent>? _liveSubscription;
  Timer? _pumpManualTimer;
  Timer? _humidifierManualTimer;
  Timer? _lightManualTimer;

  /// Timer untuk logging periodik ke history node.
  Timer? _historyTimer;

  @override
  TelemetryData build() {
    // Subscribe ke perubahan real-time di RTDB.
    _liveSubscription = _liveRef.onValue.listen(
      _onFirebaseEvent,
      onError: (error) {
        debugPrint('[TelemetryNotifier] Firebase listener error: $error');
      },
    );

    // Logging periodik ke /greenhouse/history setiap 1 menit.
    // (Untuk testing cepat; nanti ubah ke 15 menit di production.)
    _historyTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _logToHistory(),
    );

    // Cleanup semua listener & timer saat provider disposed.
    ref.onDispose(() {
      _liveSubscription?.cancel();
      _pumpManualTimer?.cancel();
      _humidifierManualTimer?.cancel();
      _lightManualTimer?.cancel();
      _historyTimer?.cancel();
    });

    // State awal: semua sensor 0, aktuator off, mode auto.
    return TelemetryData(
      temperature: 0,
      humidity: 0,
      soilMoisture: 0,
      lightIntensity: 0,
      timestamp: DateTime.now(),
    );
  }

  /// Simpan snapshot telemetri saat ini ke `/greenhouse/history`.
  ///
  /// Menggunakan `.push()` untuk auto-generate key unik.
  /// Hanya mencatat data sensor (tanpa flag aktuator).
  Future<void> _logToHistory() async {
    // Jangan log jika semua sensor masih 0 (belum ada data).
    if (state.temperature == 0 &&
        state.humidity == 0 &&
        state.soilMoisture == 0 &&
        state.lightIntensity == 0) {
      return;
    }

    try {
      await _historyRef.push().set({
        'temperature': state.temperature,
        'humidity': state.humidity,
        'soilMoisture': state.soilMoisture,
        'lightIntensity': state.lightIntensity,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[TelemetryNotifier] Error logging history: $e');
    }
  }

  /// Callback saat data di `/greenhouse/live` berubah.
  ///
  /// Parsing snapshot JSON dari ESP32 menjadi [TelemetryData].
  /// Jika field tertentu tidak ada atau format tidak valid,
  /// gunakan nilai state sebelumnya sebagai fallback.
  void _onFirebaseEvent(DatabaseEvent event) {
    try {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return;

      final map = Map<String, dynamic>.from(data);

      state = state.copyWith(
        temperature: _parseDouble(map['temperature'], state.temperature),
        humidity: _parseDouble(map['humidity'], state.humidity),
        soilMoisture: _parseDouble(map['soilMoisture'], state.soilMoisture),
        lightIntensity:
            _parseDouble(map['lightIntensity'], state.lightIntensity),
        timestamp: DateTime.now(),
        isPumpOn: _parseBool(map['isPumpOn'], state.isPumpOn),
        isHumidifierOn:
            _parseBool(map['isHumidifierOn'], state.isHumidifierOn),
        isLightOn: _parseBool(map['isLightOn'], state.isLightOn),
        isPumpManual: _parseBool(map['isPumpManual'], state.isPumpManual),
        isHumidifierManual:
            _parseBool(map['isHumidifierManual'], state.isHumidifierManual),
        isLightManual: _parseBool(map['isLightManual'], state.isLightManual),
      );
    } catch (e) {
      debugPrint('[TelemetryNotifier] Error parsing Firebase data: $e');
    }
  }

  /// Parsing aman untuk double dari data Firebase.
  /// Mengembalikan [fallback] jika parsing gagal.
  double _parseDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  /// Parsing aman untuk bool dari data Firebase.
  /// Mengembalikan [fallback] jika parsing gagal.
  bool _parseBool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// Kirim perintah manual ke aktuator via Firebase RTDB.
  ///
  /// Menggunakan **Decoupled Control Loops** — setiap aktuator
  /// memiliki lock independen di `/greenhouse/settings`:
  ///   - `isPumpAuto`
  ///   - `isHumidifierAuto`
  ///   - `isLightAuto`
  ///
  /// **Alur Manual ON** (`targetState = true`):
  ///   1. Kunci auto aktuator ini saja: `is*Auto = false`.
  ///   2. Nyalakan aktuator + set flag manual.
  ///   3. Jalankan timer [duration] untuk auto-reset.
  ///
  /// **Alur Manual OFF / Timer Expired** (`targetState = false`):
  ///   1. Matikan aktuator + reset flag manual.
  ///   2. Lepas lock: `is*Auto = true`.
  ///
  /// Aktuator lain **tidak terpengaruh** sama sekali.
  ///
  /// [actuator] — `'pump'`, `'humidifier'`, atau `'light'`
  /// [targetState] — `true` = manual ON, `false` = kembali ke auto
  /// [duration] — durasi override manual (wajib jika `targetState = true`)
  Future<void> sendManualCommand(
    String actuator,
    bool targetState, {
    Duration? duration,
  }) async {
    try {
      switch (actuator) {
        case 'pump':
          _pumpManualTimer?.cancel();
          if (targetState && duration != null) {
            // Kunci auto pompa, nyalakan aktuator.
            await _settingsRef.update({'isPumpAuto': false});
            await _liveRef.update({
              'isPumpOn': true,
              'isPumpManual': true,
            });
            // Timer: matikan dan lepas lock setelah durasi habis.
            _pumpManualTimer = Timer(duration, () async {
              try {
                await _liveRef.update({
                  'isPumpOn': false,
                  'isPumpManual': false,
                });
                await _settingsRef.update({'isPumpAuto': true});
              } catch (e) {
                debugPrint('[TelemetryNotifier] Error resetting pump: $e');
              }
            });
          } else {
            // OFF → matikan aktuator, lepas lock.
            await _liveRef.update({
              'isPumpOn': false,
              'isPumpManual': false,
            });
            await _settingsRef.update({'isPumpAuto': true});
          }

        case 'humidifier':
          _humidifierManualTimer?.cancel();
          if (targetState && duration != null) {
            await _settingsRef.update({'isHumidifierAuto': false});
            await _liveRef.update({
              'isHumidifierOn': true,
              'isHumidifierManual': true,
            });
            _humidifierManualTimer = Timer(duration, () async {
              try {
                await _liveRef.update({
                  'isHumidifierOn': false,
                  'isHumidifierManual': false,
                });
                await _settingsRef.update({'isHumidifierAuto': true});
              } catch (e) {
                debugPrint(
                    '[TelemetryNotifier] Error resetting humidifier: $e');
              }
            });
          } else {
            await _liveRef.update({
              'isHumidifierOn': false,
              'isHumidifierManual': false,
            });
            await _settingsRef.update({'isHumidifierAuto': true});
          }

        case 'light':
          _lightManualTimer?.cancel();
          if (targetState && duration != null) {
            await _settingsRef.update({'isLightAuto': false});
            await _liveRef.update({
              'isLightOn': true,
              'isLightManual': true,
            });
            _lightManualTimer = Timer(duration, () async {
              try {
                await _liveRef.update({
                  'isLightOn': false,
                  'isLightManual': false,
                });
                await _settingsRef.update({'isLightAuto': true});
              } catch (e) {
                debugPrint('[TelemetryNotifier] Error resetting light: $e');
              }
            });
          } else {
            await _liveRef.update({
              'isLightOn': false,
              'isLightManual': false,
            });
            await _settingsRef.update({'isLightAuto': true});
          }
      }
    } catch (e) {
      debugPrint('[TelemetryNotifier] Error sending command: $e');
    }
  }

  /// Memaksa UI mematikan semua aktuator saat offline (Fail-Safe Offline)
  void forceOfflineState() {
    state = state.copyWith(
      isPumpOn: false,
      isHumidifierOn: false,
      isLightOn: false,
      isPumpManual: false,
      isHumidifierManual: false,
      isLightManual: false,
    );
  }
}

/// Provider global untuk telemetri ESP32 via Firebase RTDB.
///
/// Contoh penggunaan:
/// ```dart
/// final telemetry = ref.watch(telemetryProvider);
/// print(telemetry.temperature);    // sensor reading dari RTDB
/// print(telemetry.isPumpOn);       // actuator state dari RTDB
/// print(telemetry.isPumpManual);   // manual override flag
///
/// ref.read(telemetryProvider.notifier)
///     .sendManualCommand('pump', true, duration: Duration(minutes: 5));
/// ```
final telemetryProvider =
    NotifierProvider<TelemetryNotifier, TelemetryData>(
  TelemetryNotifier.new,
);

// ═══════════════════════════════════════════════════════════════
//  Sensor History — Menyimpan riwayat data untuk chart
// ═══════════════════════════════════════════════════════════════

/// Jumlah maksimum data point yang disimpan dalam riwayat.
const int _maxHistoryLength = 20;

/// [SensorHistoryNotifier] mengumpulkan data sensor dari telemetri
/// dan menyimpan riwayat untuk keperluan grafik (fl_chart).
///
/// Konversi [TelemetryData] → [SensorData] via [TelemetryData.toSensorData()]
/// untuk backward compatibility dengan chart widget.
class SensorHistoryNotifier extends Notifier<List<SensorData>> {
  @override
  List<SensorData> build() {
    // Mendengarkan telemetri dan menambahkan ke riwayat.
    ref.listen<TelemetryData>(telemetryProvider, (previous, next) {
      final sensorData = next.toSensorData();
      final updated = [...state, sensorData];

      // Batasi panjang riwayat agar tidak membengkak.
      if (updated.length > _maxHistoryLength) {
        state = updated.sublist(updated.length - _maxHistoryLength);
      } else {
        state = updated;
      }
    });

    return <SensorData>[];
  }
}

/// Provider untuk riwayat data sensor (digunakan oleh chart/grafik).
///
/// Contoh penggunaan:
/// ```dart
/// final history = ref.watch(sensorHistoryProvider);
/// // history adalah List<SensorData> dengan maks 20 data point
/// ```
final sensorHistoryProvider =
    NotifierProvider<SensorHistoryNotifier, List<SensorData>>(
  SensorHistoryNotifier.new,
);

// ═══════════════════════════════════════════════════════════════
//  Chart Metric Selection — Notifier (Riverpod 3.x compatible)
// ═══════════════════════════════════════════════════════════════

/// Indeks metrik sensor yang sedang ditampilkan pada grafik.
///
/// Nilai:
/// - `0` → Suhu (°C)
/// - `1` → Kelembaban (%)
/// - `2` → Soil Moisture (%)
/// - `3` → LDR / Intensitas Cahaya (lux)
class SelectedChartMetricNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Pilih metrik berdasarkan [index].
  void select(int index) {
    state = index;
  }
}

/// Provider untuk metrik grafik yang sedang dipilih.
///
/// Contoh penggunaan:
/// ```dart
/// final selected = ref.watch(selectedChartMetricProvider);
/// ref.read(selectedChartMetricProvider.notifier).select(1);
/// ```
final selectedChartMetricProvider =
    NotifierProvider<SelectedChartMetricNotifier, int>(
  SelectedChartMetricNotifier.new,
);

// ═══════════════════════════════════════════════════════════════
//  ESP32 Presence System — Deteksi status online via Heartbeat
// ═══════════════════════════════════════════════════════════════

/// Notifier yang memantau detak jantung ESP32 dari `/greenhouse/live/lastHeartbeat`.
///
/// ESP32 mengirimkan waktu server terbaru setiap 5 detik.
/// Provider ini membandingkan `lastHeartbeat` dengan `DateTime.now()`
/// setiap 2 detik. Jika selisihnya > 15 detik, perangkat dianggap Offline.
class EspOnlineNotifier extends Notifier<bool> {
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _sub;
  int _lastHeartbeat = 0;

  @override
  bool build() {
    final hbRef =
        FirebaseDatabase.instance.ref('greenhouse/live/lastHeartbeat');

    // Dengarkan pembaruan heartbeat dari Firebase
    _sub = hbRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is int) {
        _lastHeartbeat = value;
      } else if (value is num) {
        _lastHeartbeat = value.toInt();
      }
      _checkStatus();
    }, onError: (error) {
      debugPrint('[EspOnlineNotifier] Listener error: $error');
    });

    // Jalankan timer lokal setiap 2 detik untuk evaluasi offline/online
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkStatus();
    });

    // Cleanup saat provider di-dispose
    ref.onDispose(() {
      _timer?.cancel();
      _sub?.cancel();
    });

    // State awal (Offline sampai mendapat heartbeat pertama)
    return false;
  }

  void _checkStatus() {
    if (_lastHeartbeat == 0) return; // Belum ada data

    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - _lastHeartbeat;

    // Jika selisih > 15 detik, anggap Offline.
    final isOnline = diff <= 15000;
    
    // Update state jika ada perubahan
    if (state != isOnline) {
      state = isOnline;
      if (!isOnline) {
        // Reset state aktuator di UI menjadi OFF saat alat fisik offline
        ref.read(telemetryProvider.notifier).forceOfflineState();
      }
    }
  }
}

final espOnlineProvider = NotifierProvider<EspOnlineNotifier, bool>(
  EspOnlineNotifier.new,
);
