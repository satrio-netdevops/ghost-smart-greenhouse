import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sensor_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/threshold_provider.dart';
import '../widgets/actuator_card.dart';
import '../widgets/sensor_card.dart';
import '../widgets/sensor_chart_widget.dart';
import '../widgets/timer_config_dialog.dart';
import 'user_management_screen.dart';

/// DashboardScreen — Layar utama aplikasi Smart Greenhouse.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider);
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isOnline = ref.watch(espOnlineProvider);

    return Scaffold(
      appBar: _buildAppBar(context, ref, user, isOnline),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user != null) _buildUserBanner(context, user),
              if (user != null) const SizedBox(height: 24),
              if (!isOnline) _buildOfflineBanner(context),
              if (!isOnline) const SizedBox(height: 16),
              _buildActuatorSection(context, ref, telemetry, isOnline),
              const SizedBox(height: 28),
              _buildSensorExpansion(context, telemetry),
              const SizedBox(height: 28),
              _buildSectionHeader(context,
                  icon: Icons.show_chart_rounded,
                  title: 'Grafik Sensor Real-time'),
              const SizedBox(height: 14),
              _buildChartCard(context),
              const SizedBox(height: 16),
              _buildExportButton(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WidgetRef ref, UserModel? user, bool isOnline) {
    final theme = Theme.of(context);
    final statusColor = isOnline ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final statusLabel = isOnline ? 'Online' : 'Offline';
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'GHOST Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22.0,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
      actions: [
        // Admin: Manajemen Pengguna
        if (user != null && user.isAdmin)
          IconButton(
            icon: const Icon(Icons.manage_accounts, color: Colors.white),
            tooltip: 'Manajemen Pengguna',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen())),
          ),
        // Admin: Threshold Settings (RBAC)
        if (user != null && user.isAdmin)
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'Pengaturan Threshold',
            onPressed: () => _showThresholdSettings(context, ref),
          ),
        // ESP32 Status (dari Presence System)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6), width: 2),
                boxShadow: [BoxShadow(
                    color: statusColor.withValues(alpha: 0.5),
                    blurRadius: 6, spreadRadius: 1)],
              ),
            ),
          ]),
        ),
        // Logout
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          tooltip: 'Logout',
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
        const SizedBox(width: 4),
      ],
    ),
      ),
    );
  }

  // ─── User Welcome Banner ─────────────────────────────────

  Widget _buildUserBanner(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, ${user.name}',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(user.email,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: user.isAdmin
                ? const Color(0xFFFFA000).withValues(alpha: 0.12)
                : cs.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(user.isAdmin ? 'Admin' : 'User',
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: user.isAdmin
                      ? const Color(0xFFFFA000)
                      : cs.secondary)),
        ),
      ]),
    );
  }

  // ─── Section Header ──────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context,
      {required IconData icon, required String title, Widget? trailing}) {
    final theme = Theme.of(context);
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.primary),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface)),
      if (trailing != null) ...[const SizedBox(width: 8), trailing],
    ]);
  }

  // ─── Offline Warning Banner ──────────────────────────────

  Widget _buildOfflineBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.25),
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off_rounded,
              size: 18, color: Color(0xFFE53935)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Koneksi Terputus',
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE53935))),
              const SizedBox(height: 2),
              Text('Memperkirakan perangkat ESP32 offline.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ]),
    );
  }

  // ─── Actuator Section ────────────────────────────────────

  Widget _buildActuatorSection(
      BuildContext context, WidgetRef ref, TelemetryData telemetry,
      bool isOnline) {
    final theme = Theme.of(context);

    // Badge mode indicator
    Widget? modeBadge;
    if (telemetry.hasManualOverride) {
      modeBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFA000).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('Manual Override',
            style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFA000))),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isOnline ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context,
              icon: Icons.tune_rounded,
              title: 'Kontrol Aktuator',
              trailing: modeBadge),
          const SizedBox(height: 14),
          Row(children: [
            ActuatorCard(
              label: 'Pompa DC',
              icon: Icons.water_drop_rounded,
              isOn: isOnline ? telemetry.isPumpOn : false,
              isManualOverride: isOnline ? telemetry.isPumpManual : false,
              onToggle: isOnline
                  ? (v) => _handleActuatorToggle(
                      context, ref, 'pump', 'Pompa DC', v)
                  : null,
              activeColor: const Color(0xFF2196F3),
            ),
            const SizedBox(width: 10),
            ActuatorCard(
              label: 'Humidifier',
              icon: Icons.air_rounded,
              isOn: isOnline ? telemetry.isHumidifierOn : false,
              isManualOverride: isOnline ? telemetry.isHumidifierManual : false,
              onToggle: isOnline
                  ? (v) => _handleActuatorToggle(
                      context, ref, 'humidifier', 'Humidifier', v)
                  : null,
              activeColor: const Color(0xFF00BCD4),
            ),
            const SizedBox(width: 10),
            ActuatorCard(
              label: 'Lampu',
              icon: Icons.lightbulb_rounded,
              isOn: isOnline ? telemetry.isLightOn : false,
              isManualOverride: isOnline ? telemetry.isLightManual : false,
              onToggle: isOnline
                  ? (v) => _handleActuatorToggle(
                      context, ref, 'light', 'Lampu', v)
                  : null,
              activeColor: const Color(0xFFFFA726),
            ),
          ]),
        ],
      ),
    );
  }

  /// Handle switch toggle: ON → show TimerConfigDialog, OFF → cancel & auto.
  Future<void> _handleActuatorToggle(BuildContext context, WidgetRef ref,
      String actuator, String label, bool newValue) async {
    final notifier = ref.read(telemetryProvider.notifier);

    if (newValue) {
      // ON → show timer config dialog
      final duration = await showDialog<Duration>(
        context: context,
        builder: (_) => TimerConfigDialog(actuatorName: label),
      );
      if (duration != null) {
        notifier.sendManualCommand(actuator, true, duration: duration);
      }
    } else {
      // OFF → cancel manual timer, return to auto
      notifier.sendManualCommand(actuator, false);
    }
  }

  // ─── Sensor Expansion ────────────────────────────────────

  Widget _buildSensorExpansion(
      BuildContext context, TelemetryData telemetry) {
    final theme = Theme.of(context);

    final sensorConfigs = [
      (label: 'Suhu', icon: Icons.thermostat_rounded,
       color: const Color(0xFFE53935), unit: '°C',
       value: telemetry.temperature.toStringAsFixed(1)),
      (label: 'Kelembaban', icon: Icons.water_drop_outlined,
       color: const Color(0xFF1E88E5), unit: '%',
       value: telemetry.humidity.toStringAsFixed(1)),
      (label: 'Soil Moisture', icon: Icons.grass_rounded,
       color: const Color(0xFF43A047), unit: '%',
       value: telemetry.soilMoisture.toStringAsFixed(1)),
      (label: 'LDR', icon: Icons.wb_sunny_rounded,
       color: const Color(0xFFFFA000), unit: 'lux',
       value: telemetry.lightIntensity.toStringAsFixed(0)),
    ];

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.sensors_rounded,
              size: 18, color: theme.colorScheme.primary),
        ),
        title: Text('Pembacaan Sensor Real-time',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface)),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: sensorConfigs
                .map((c) => SensorCard(
                    label: c.label,
                    icon: c.icon,
                    accentColor: c.color,
                    unit: c.unit,
                    value: c.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Chart Card ──────────────────────────────────────────

  Widget _buildChartCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 16, 8),
          child: SensorChartWidget(),
        ),
      ),
    );
  }

  // ─── FAB Ekspor ──────────────────────────────────────────

  Widget _buildExportButton(BuildContext context, WidgetRef ref) {
    return Center(
      child: FilledButton.icon(
        onPressed: () async {
          final historyState = ref.read(historyProvider);
          if (historyState.data.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Belum ada data historis untuk diekspor'),
              ]),
              backgroundColor: const Color(0xFFFFA000),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              duration: const Duration(seconds: 2),
            ));
            return;
          }
          await ref.read(historyProvider.notifier).exportToCsv();
        },
        icon: const Icon(Icons.file_download_rounded),
        label: const Text('Ekspor CSV'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ─── Threshold Settings Bottom Sheet (Admin Only) ────────

  void _showThresholdSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ThresholdSettingsSheet(ref: ref),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Threshold Settings Bottom Sheet (Stateful)
// ═══════════════════════════════════════════════════════════════

class _ThresholdSettingsSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ThresholdSettingsSheet({required this.ref});

  @override
  ConsumerState<_ThresholdSettingsSheet> createState() =>
      _ThresholdSettingsSheetState();
}

class _ThresholdSettingsSheetState
    extends ConsumerState<_ThresholdSettingsSheet> {
  late RangeValues _soilRange;
  late RangeValues _tempRange;
  late RangeValues _lightRange;

  @override
  void initState() {
    super.initState();
    final config = widget.ref.read(thresholdProvider);
    _soilRange = RangeValues(config.soilMoistureMin, config.soilMoistureMax);
    _tempRange = RangeValues(config.temperatureMin, config.temperatureMax);
    _lightRange = RangeValues(config.lightMin, config.lightMax);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag Handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Text('Pengaturan Threshold',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Atur ambang batas sensor untuk kontrol otomatis aktuator.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),

        // Soil Moisture
        _buildRangeSection(
          theme: theme,
          title: 'Soil Moisture → Pompa',
          icon: Icons.grass_rounded,
          color: const Color(0xFF43A047),
          range: _soilRange,
          min: 0, max: 100, unit: '%',
          onChanged: (v) {
            setState(() => _soilRange = v);
            ref.read(thresholdProvider.notifier)
                .updateSoilMoisture(min: v.start, max: v.end);
          },
        ),
        const SizedBox(height: 16),

        // Temperature
        _buildRangeSection(
          theme: theme,
          title: 'Suhu → Humidifier',
          icon: Icons.thermostat_rounded,
          color: const Color(0xFFE53935),
          range: _tempRange,
          min: 15, max: 45, unit: '°C',
          onChanged: (v) {
            setState(() => _tempRange = v);
            ref.read(thresholdProvider.notifier)
                .updateTemperature(min: v.start, max: v.end);
          },
        ),
        const SizedBox(height: 16),

        // Light
        _buildRangeSection(
          theme: theme,
          title: 'Cahaya → Lampu',
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFFFFA000),
          range: _lightRange,
          min: 0, max: 30000, unit: ' lux',
          onChanged: (v) {
            setState(() => _lightRange = v);
            ref.read(thresholdProvider.notifier)
                .updateLight(min: v.start, max: v.end);
          },
        ),
        const SizedBox(height: 20),

        // Reset Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(thresholdProvider.notifier).resetToDefaults();
              final d = const ThresholdConfig();
              setState(() {
                _soilRange = RangeValues(d.soilMoistureMin, d.soilMoistureMax);
                _tempRange = RangeValues(d.temperatureMin, d.temperatureMax);
                _lightRange = RangeValues(d.lightMin, d.lightMax);
              });
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset ke Default'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildRangeSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required RangeValues range,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<RangeValues> onChanged,
  }) {
    String formatValue(num v) {
      final str = v.round().toString();
      // Regex for thousands separator (e.g. 30000 -> 30.000)
      return str.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          '${formatValue(range.start)}$unit – ${formatValue(range.end)}$unit',
          style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700, color: color),
        ),
      ]),
      RangeSlider(
        values: range,
        min: min, max: max,
        divisions: (max - min) > 1000 ? 300 : (max - min).round(),
        activeColor: color,
        labels: RangeLabels(
            '${formatValue(range.start)}$unit', '${formatValue(range.end)}$unit'),
        onChanged: onChanged,
      ),
    ]);
  }
}
