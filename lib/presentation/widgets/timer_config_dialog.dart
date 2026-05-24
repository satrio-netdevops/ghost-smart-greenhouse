import 'package:flutter/material.dart';

/// Material 3 dialog untuk memilih durasi override manual aktuator.
///
/// Menampilkan slider 1–60 menit. Jika user menekan 'Nyalakan',
/// mengembalikan [Duration] yang dipilih. Jika dibatalkan, return `null`.
///
/// Penggunaan:
/// ```dart
/// final duration = await showDialog<Duration>(
///   context: context,
///   builder: (_) => TimerConfigDialog(actuatorName: 'Pompa DC'),
/// );
/// ```
class TimerConfigDialog extends StatefulWidget {
  /// Nama aktuator untuk ditampilkan di judul dialog.
  final String actuatorName;

  const TimerConfigDialog({super.key, required this.actuatorName});

  @override
  State<TimerConfigDialog> createState() => _TimerConfigDialogState();
}

class _TimerConfigDialogState extends State<TimerConfigDialog> {
  double _minutes = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.timer_rounded,
          size: 28,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        'Manual Override',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nyalakan ${widget.actuatorName} secara manual '
            'selama berapa menit?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Duration Display ──────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              '${_minutes.round()} menit',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Slider ────────────────────────────────
          Row(
            children: [
              Text(
                '1',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _minutes,
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: '${_minutes.round()} min',
                  onChanged: (v) => setState(() => _minutes = v),
                ),
              ),
              Text(
                '60',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            'Setelah waktu habis, aktuator kembali ke mode otomatis.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              Duration(minutes: _minutes.round()),
            );
          },
          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
          label: const Text('Nyalakan'),
        ),
      ],
    );
  }
}
