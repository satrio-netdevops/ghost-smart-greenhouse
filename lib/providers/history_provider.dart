import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/sensor_data.dart';

// ═══════════════════════════════════════════════════════════════
//  History Provider — Analitik Historis & Ekspor CSV
// ═══════════════════════════════════════════════════════════════

/// [HistoryNotifier] mengambil data historis sensor dari Firebase RTDB
/// node `/greenhouse/history` dan menyediakan fungsi ekspor CSV.
///
/// Data diurutkan ascending (lama → baru) berdasarkan timestamp.
class HistoryNotifier extends Notifier<HistoryState> {
  /// Referensi ke node `/greenhouse/history` di RTDB.
  DatabaseReference get _historyRef =>
      FirebaseDatabase.instance.ref('greenhouse/history');

  @override
  HistoryState build() {
    // Jadwalkan fetch ke microtask agar build() bisa return state awal
    // terlebih dahulu — mencegah "read state of uninitialized provider".
    Future.microtask(() => fetchHistory());
    return const HistoryState();
  }

  /// Mengambil 50 data historis terbaru dari RTDB.
  ///
  /// Query: `/greenhouse/history` → orderByChild('timestamp')
  /// → limitToLast(50).
  /// Data diurutkan ascending berdasarkan timestamp.
  Future<void> fetchHistory() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final snapshot = await _historyRef
          .orderByChild('timestamp')
          .limitToLast(50)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        state = state.copyWith(isLoading: false, data: []);
        return;
      }

      final rawMap = snapshot.value as Map<dynamic, dynamic>;
      final List<SensorData> entries = [];

      for (final entry in rawMap.values) {
        try {
          if (entry is! Map) continue;
          final map = Map<String, dynamic>.from(entry);

          entries.add(SensorData(
            temperature: _parseDouble(map['temperature'], 0),
            humidity: _parseDouble(map['humidity'], 0),
            soilMoisture: _parseDouble(map['soilMoisture'], 0),
            lightIntensity: _parseDouble(map['lightIntensity'], 0),
            timestamp: _parseTimestamp(map['timestamp']),
          ));
        } catch (e) {
          debugPrint('[HistoryNotifier] Error parsing entry: $e');
        }
      }

      // Urutkan ascending (lama → baru).
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      state = state.copyWith(isLoading: false, data: entries);
    } catch (e) {
      debugPrint('[HistoryNotifier] Error fetching history: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat data historis: $e',
      );
    }
  }

  /// Ekspor data historis ke file CSV dan tampilkan dialog share.
  ///
  /// Format CSV:
  /// ```
  /// Waktu,Suhu,Kelembaban,Soil Moisture,LDR
  /// 2026-05-18 01:30:00,28.5,72.0,45.2,580
  /// ```
  Future<void> exportToCsv() async {
    if (state.data.isEmpty) return;

    try {
      // Bangun string CSV.
      final buffer = StringBuffer();
      buffer.writeln('Waktu,Suhu,Kelembaban,Soil Moisture,LDR');

      for (final entry in state.data) {
        final timeStr = '${entry.timestamp.year}-'
            '${entry.timestamp.month.toString().padLeft(2, '0')}-'
            '${entry.timestamp.day.toString().padLeft(2, '0')} '
            '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
            '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
            '${entry.timestamp.second.toString().padLeft(2, '0')}';

        buffer.writeln(
          '$timeStr,'
          '${entry.temperature.toStringAsFixed(1)},'
          '${entry.humidity.toStringAsFixed(1)},'
          '${entry.soilMoisture.toStringAsFixed(1)},'
          '${entry.lightIntensity.toStringAsFixed(0)}',
        );
      }

      // Tulis ke file.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ghost_history_export.csv');
      await file.writeAsString(buffer.toString());

      // Tampilkan dialog share.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'GHOST Smart Greenhouse - Data Historis',
        ),
      );
    } catch (e) {
      debugPrint('[HistoryNotifier] Error exporting CSV: $e');
      state = state.copyWith(
        errorMessage: 'Gagal mengekspor CSV: $e',
      );
    }
  }

  // ── Parsing helpers ──────────────────────────────────────

  double _parseDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

// ═══════════════════════════════════════════════════════════════
//  History State
// ═══════════════════════════════════════════════════════════════

/// State untuk data historis sensor.
@immutable
class HistoryState {
  /// Data historis sensor, diurutkan ascending.
  final List<SensorData> data;

  /// Apakah sedang memuat data.
  final bool isLoading;

  /// Pesan error jika terjadi kesalahan.
  final String? errorMessage;

  const HistoryState({
    this.data = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  HistoryState copyWith({
    List<SensorData>? data,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HistoryState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HistoryState &&
        listEquals(other.data, data) &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(data, isLoading, errorMessage);
}

// ═══════════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════════

/// Provider global untuk data historis sensor dan ekspor CSV.
///
/// Contoh penggunaan:
/// ```dart
/// final history = ref.watch(historyProvider);
/// final data = history.data;    // List<SensorData>
///
/// // Refresh data
/// ref.read(historyProvider.notifier).fetchHistory();
///
/// // Ekspor CSV
/// ref.read(historyProvider.notifier).exportToCsv();
/// ```
final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);
