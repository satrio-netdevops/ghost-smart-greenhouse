import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_management_provider.dart';

/// Warna utama IPB — Biru Tua (#003366).
const _ipbDarkBlue = Color(0xFF003366);

/// UserManagementScreen — Layar CRUD Manajemen Pengguna (Admin Only).
///
/// Fitur:
/// - AppBar bertekstur Biru Tua IPB
/// - ListView Card estetik untuk setiap pengguna
/// - Dropdown untuk mengubah role
/// - Tombol hapus dengan konfirmasi dialog
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userManagementProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manajemen Pengguna',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: _ipbDarkBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: users.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _ipbDarkBlue),
        ),
        error: (error, stackTrace) => Center(
          child: Text('Terjadi kesalahan: $error'),
        ),
        data: (userList) {
          if (userList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada pengguna terdaftar.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: userList.length,
            itemBuilder: (context, index) {
              final user = userList[index];
              return _UserCard(user: user);
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  User Card Widget
// ═══════════════════════════════════════════════════════════════

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────
            CircleAvatar(
              radius: 22,
              backgroundColor: user.isAdmin
                  ? const Color(0xFFFFA000).withValues(alpha: 0.12)
                  : _ipbDarkBlue.withValues(alpha: 0.10),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: user.isAdmin
                      ? const Color(0xFFFFA000)
                      : _ipbDarkBlue,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Name & Email ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Trailing: Dropdown + Delete ─────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Role Dropdown ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: user.role,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
                        DropdownMenuItem(
                          value: 'user',
                          child: Text('User'),
                        ),
                      ],
                      onChanged: (newRole) {
                        if (newRole != null && newRole != user.role) {
                          ref
                              .read(userManagementProvider.notifier)
                              .changeUserRole(user.id, newRole);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Role ${user.name} diubah menjadi ${newRole == 'admin' ? 'Admin' : 'User'}.',
                              ),
                              backgroundColor: _ipbDarkBlue,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // ── Delete Button ──
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  color: const Color(0xFFE53935),
                  tooltip: 'Hapus Pengguna',
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog konfirmasi sebelum menghapus pengguna.
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Hapus Pengguna?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${user.name}" dari sistem?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () {
              ref
                  .read(userManagementProvider.notifier)
                  .deleteUser(user.id);
              Navigator.of(ctx).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.name} berhasil dihapus.'),
                  backgroundColor: const Color(0xFFE53935),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                ),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
