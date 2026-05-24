import 'package:flutter/material.dart';

/// Widget kartu kontrol aktuator dengan icon, label, switch on/off,
/// dan indikator mode manual override.
///
/// Didesain untuk ditampilkan dalam Row di bagian 'Kontrol Aktuator'
/// pada DashboardScreen.
class ActuatorCard extends StatelessWidget {
  /// Nama aktuator (misal: 'Pompa DC').
  final String label;

  /// Icon yang merepresentasikan aktuator.
  final IconData icon;

  /// Apakah aktuator sedang dalam keadaan aktif.
  final bool isOn;

  /// Callback saat switch di-toggle. `null` jika disabled (offline).
  final ValueChanged<bool>? onToggle;

  /// Warna aksen saat aktuator aktif.
  final Color activeColor;

  /// Apakah aktuator sedang dalam mode manual override.
  final bool isManualOverride;

  const ActuatorCard({
    super.key,
    required this.label,
    required this.icon,
    required this.isOn,
    required this.onToggle,
    required this.activeColor,
    this.isManualOverride = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = isOn ? activeColor : theme.colorScheme.outline;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isOn
              ? activeColor.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOn
                ? activeColor.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isOn
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ──────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: effectiveColor,
                ),
              ),

              const SizedBox(height: 8),

              // ── Label ─────────────────────────────
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isOn
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Manual Override Indicator ─────────
              if (isManualOverride) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Manual',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFA000),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // ── Switch ────────────────────────────
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch(
                    value: isOn,
                    onChanged: onToggle,
                    activeThumbColor: activeColor,
                    activeTrackColor: activeColor.withValues(alpha: 0.35),
                    inactiveThumbColor: theme.colorScheme.outline,
                    inactiveTrackColor:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
