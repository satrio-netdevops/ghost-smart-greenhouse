import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  User List Notifier — Real-time dari Firebase RTDB
// ═══════════════════════════════════════════════════════════════

/// [UserListNotifier] mengelola daftar pengguna dari Realtime Database.
class UserListNotifier extends StreamNotifier<List<UserModel>> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('users');

  @override
  Stream<List<UserModel>> build() {
    return _dbRef.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries.map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        return UserModel(
          id: e.key.toString(),
          name: map['name']?.toString() ?? 'Unknown',
          email: map['email']?.toString() ?? '',
          role: map['role']?.toString() ?? 'user',
        );
      }).toList();
    });
  }

  /// Menghapus pengguna berdasarkan [id] di Firebase RTDB.
  Future<void> deleteUser(String id) async {
    try {
      await _dbRef.child(id).remove();
    } catch (e) {
      // Handle error optionally
    }
  }

  /// Mengubah role pengguna [id] menjadi [newRole] di Firebase RTDB.
  Future<void> changeUserRole(String id, String newRole) async {
    try {
      await _dbRef.child(id).update({'role': newRole});
    } catch (e) {
      // Handle error optionally
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════════

/// Provider global untuk manajemen daftar pengguna (Real-time).
final userManagementProvider =
    StreamNotifierProvider<UserListNotifier, List<UserModel>>(
  UserListNotifier.new,
);
