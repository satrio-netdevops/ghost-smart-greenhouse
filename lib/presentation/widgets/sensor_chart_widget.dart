import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sensor_data.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/history_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  Konfigurasi Metrik Sensor
// ═══════════════════════════════════════════════════════════════

/// Konfigurasi visual dan data untuk setiap metrik sensor.
class _MetricConfig {
  final String label;
  final String unit;
  final Color lineColor;
  final Color gradientEnd;
  final double fixedMinY;
  final double fixedMaxY;
  final double yInterval;
  final double Function(SensorData) getValue;

  const _MetricConfig({
    required this.label,
    required this.unit,
    required this.lineColor,
    required this.gradientEnd,
    required this.fixedMinY,
    required this.fixedMaxY,
    required this.yInterval,
    required this.getValue,
  });
}

/// Daftar konfigurasi untuk 4 metrik sensor.
final _metricConfigs = <_MetricConfig>[
  _MetricConfig(
    label: 'Suhu',
    unit: '°C',
    lineColor: const Color(0xFFE53935),
    gradientEnd: const Color(0xFFEF9A9A),
    fixedMinY: 0,
    fixedMaxY: 50,
    yInterval: 10,
    getValue: (s) => s.temperature,
  ),
  _MetricConfig(
    label: 'Kelembaban',
    unit: '%',
    lineColor: const Color(0xFF1E88E5),
    gradientEnd: const Color(0xFF90CAF9),
    fixedMinY: 0,
    fixedMaxY: 100,
    yInterval: 20,
    getValue: (s) => s.humidity,
  ),
  _MetricConfig(
    label: 'Tanah',
    unit: '%',
    lineColor: const Color(0xFF43A047),
    gradientEnd: const Color(0xFFA5D6A7),
    fixedMinY: 0,
    fixedMaxY: 100,
    yInterval: 20,
    getValue: (s) => s.soilMoisture,
  ),
  _MetricConfig(
    label: 'Cahaya',
    unit: 'lux',
    lineColor: const Color(0xFFFFA000),
    gradientEnd: const Color(0xFFFFE082),
    fixedMinY: 0,
    fixedMaxY: 2000,
    yInterval: 500,
    getValue: (s) => s.lightIntensity,
  ),
];

// ═══════════════════════════════════════════════════════════════
//  Widget Grafik Sensor
// ═══════════════════════════════════════════════════════════════

/// Widget grafik sensor real-time menggunakan fl_chart.
///
/// Menampilkan data dari [sensorHistoryProvider] sebagai LineChart
/// dengan garis mulus, gradien area, tooltip interaktif, dan
/// filter ChoiceChip untuk memilih metrik.
class SensorChartWidget extends ConsumerWidget {
  const SensorChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final history = historyState.data;
    final selectedIndex = ref.watch(selectedChartMetricProvider);
    final theme = Theme.of(context);
    final config = _metricConfigs[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter Chips ────────────────────────────
        _buildMetricChips(context, ref, selectedIndex),

        const SizedBox(height: 16),

        // ── Grafik ──────────────────────────────────
        SizedBox(
          height: 200,
          child: history.isEmpty
              ? _buildEmptyState(theme)
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: LineChart(
                    _buildChartData(history, theme, config),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Metric Selection Chips
  // ─────────────────────────────────────────────────────────

  Widget _buildMetricChips(
    BuildContext context,
    WidgetRef ref,
    int selectedIndex,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_metricConfigs.length, (index) {
          final config = _metricConfigs[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.only(
              right: index < _metricConfigs.length - 1 ? 8 : 0,
            ),
            child: ChoiceChip(
              label: Text(config.label),
              selected: isSelected,
              onSelected: (_) {
                ref.read(selectedChartMetricProvider.notifier).select(index);
              },
              selectedColor: config.lineColor.withValues(alpha: 0.15),
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              side: BorderSide(
                color: isSelected
                    ? config.lineColor.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: 1.5,
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? config.lineColor
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Empty State
  // ─────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Menunggu data sensor...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Grafik akan muncul dalam beberapa detik',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Chart Data Configuration
  // ─────────────────────────────────────────────────────────

  LineChartData _buildChartData(
    List<SensorData> history,
    ThemeData theme,
    _MetricConfig config,
  ) {
    final spots = _buildSpots(history, config);

    return LineChartData(
      // ── Grid ────────────────────────────────────
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: config.yInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          strokeWidth: 1,
          dashArray: [6, 4],
        ),
      ),

      // ── Border ──────────────────────────────────
      borderData: FlBorderData(show: false),

      // ── Tooltip ─────────────────────────────────
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBorderRadius: BorderRadius.circular(12),
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          getTooltipColor: (_) => config.lineColor.withValues(alpha: 0.9),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              final sensorData = index < history.length ? history[index] : null;
              final timeStr = sensorData != null
                  ? '${sensorData.timestamp.hour.toString().padLeft(2, '0')}:'
                        '${sensorData.timestamp.minute.toString().padLeft(2, '0')}:'
                        '${sensorData.timestamp.second.toString().padLeft(2, '0')}'
                  : '';

              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} ${config.unit}\n',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: timeStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: config.lineColor.withValues(alpha: 0.4),
                strokeWidth: 1.5,
                dashArray: [4, 3],
              ),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 5,
                      color: Colors.white,
                      strokeWidth: 2.5,
                      strokeColor: config.lineColor,
                    ),
              ),
            );
          }).toList();
        },
      ),

      // ── Sumbu X (Waktu) ─────────────────────────
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _calculateXInterval(history.length),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= history.length) {
                return const SizedBox.shrink();
              }
              final ts = history[index].timestamp;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${ts.hour.toString().padLeft(2, '0')}:'
                  '${ts.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),

        // ── Sumbu Y (Dinamis) ─────────────────────────
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: config.yInterval,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ),

      // ── Rentang Y (Absolut per metrik) ─────────────
      minY: config.fixedMinY,
      maxY: config.fixedMaxY,

      // ── Layer 2: Clip kanvas agar garis tidak menembus batas ──
      clipData: FlClipData.all(),

      // ── Garis Data ────────────────────────────────
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: config.lineColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              // Hanya tampilkan dot pada data point terakhir
              if (index == spots.length - 1) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: config.lineColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              }
              return FlDotCirclePainter(
                radius: 0,
                color: Colors.transparent,
                strokeWidth: 0,
                strokeColor: Colors.transparent,
              );
            },
          ),

          // ── Gradien area di bawah garis ────────────
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                config.lineColor.withValues(alpha: 0.25),
                config.gradientEnd.withValues(alpha: 0.05),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────

  /// Membangun list FlSpot dari data sensor berdasarkan metrik aktif.
  ///
  /// Layer 1: Nilai Y di-clamp ke [fixedMinY, fixedMaxY] agar data
  /// yang anomali (noise sensor) tidak menyebabkan garis keluar batas.
  List<FlSpot> _buildSpots(List<SensorData> history, _MetricConfig config) {
    return List.generate(
      history.length,
      (i) {
        final rawY = config.getValue(history[i]);
        final clampedY = rawY.clamp(config.fixedMinY, config.fixedMaxY);
        return FlSpot(i.toDouble(), clampedY);
      },
    );
  }

  /// Menghitung interval label sumbu X agar tidak terlalu rapat.
  double _calculateXInterval(int dataLength) {
    if (dataLength <= 5) return 1;
    if (dataLength <= 10) return 2;
    return (dataLength / 5).ceilToDouble();
  }
}
