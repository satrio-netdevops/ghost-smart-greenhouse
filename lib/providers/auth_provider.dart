import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════
//  User Model
// ═══════════════════════════════════════════════════════════════

/// Representasi data pengguna yang sedang aktif.
@immutable
class UserModel {
  /// ID unik pengguna (Firebase UID).
  final String id;

  /// Nama lengkap pengguna.
  final String name;

  /// Alamat email pengguna.
  final String email;

  /// Role pengguna: `'admin'` atau `'user'`.
  final String role;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  /// Apakah pengguna memiliki role admin.
  bool get isAdmin => role == 'admin';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(id, name, email, role);

  @override
  String toString() => 'UserModel(id: $id, name: $name, email: $email, role: $role)';
}

// ═══════════════════════════════════════════════════════════════
//  Auth State Model
// ═══════════════════════════════════════════════════════════════

/// Representasi state autentikasi pengguna.
@immutable
class AuthState {
  /// Data pengguna yang sedang login. `null` jika belum terautentikasi.
  final UserModel? currentUser;

  /// Apakah sedang memproses login/signup (untuk animasi loading).
  final bool isLoading;

  /// Pesan error jika login/signup gagal.
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Apakah pengguna sudah terautentikasi.
  bool get isAuthenticated => currentUser != null;

  AuthState copyWith({
    UserModel? currentUser,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.currentUser == currentUser &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(currentUser, isLoading, errorMessage);
}

// ═══════════════════════════════════════════════════════════════
//  RBAC — Firebase Realtime Database
// ═══════════════════════════════════════════════════════════════
//
//  Struktur node: /users/{uid}/
//    ├── email: String
//    ├── name:  String
//    └── role:  'admin' | 'user'
//

// ═══════════════════════════════════════════════════════════════
//  Auth Notifier — Firebase Integration
// ═══════════════════════════════════════════════════════════════

/// [AuthNotifier] mengelola alur autentikasi pengguna via Firebase Auth.
///
/// Menyediakan:
/// - [login] — autentikasi dengan Firebase `signInWithEmailAndPassword`
/// - [register] — registrasi dengan Firebase `createUserWithEmailAndPassword`
/// - [logout] — sign out dari Firebase dan reset state
class AuthNotifier extends Notifier<AuthState> {
  /// Instance FirebaseAuth.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Referensi root Firebase Realtime Database.
  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  @override
  AuthState build() {
    // Cek apakah sudah ada user yang terautentikasi (persistent session).
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      // Mulai dengan loading state, lalu fetch role dari RTDB secara async.
      _restoreSession(firebaseUser);
      return const AuthState(isLoading: true);
    }
    return const AuthState();
  }

  /// Memulihkan sesi pengguna dengan fetch role dari RTDB.
  Future<void> _restoreSession(User firebaseUser) async {
    try {
      final role = await _fetchUserRole(firebaseUser.uid);
      state = state.copyWith(
        currentUser: UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'User',
          email: firebaseUser.email ?? '',
          role: role,
        ),
        isLoading: false,
      );
    } catch (_) {
      // Jika fetch gagal, tetap autentikasi dengan role fallback.
      state = state.copyWith(
        currentUser: UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'User',
          email: firebaseUser.email ?? '',
          role: 'user',
        ),
        isLoading: false,
      );
    }
  }

  /// Mengambil role pengguna dari node `/users/{uid}/role` di RTDB.
  ///
  /// Mengembalikan `'user'` sebagai fallback jika data tidak ditemukan.
  Future<String> _fetchUserRole(String uid) async {
    final snapshot = await _db.child('users/$uid/role').get();
    if (snapshot.exists && snapshot.value != null) {
      return snapshot.value.toString();
    }
    return 'user';
  }

  /// Login via Firebase Auth dengan role dari RTDB.
  ///
  /// Setelah autentikasi berhasil, role diambil dari `/users/{uid}/role`
  /// di Firebase Realtime Database. Jika data tidak ditemukan, role
  /// fallback ke `'user'`.
  Future<void> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(errorMessage: 'Email dan password harus diisi.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Terjadi kesalahan saat login.',
        );
        return;
      }

      // Fetch role dari RTDB.
      final role = await _fetchUserRole(user.uid);

      state = state.copyWith(
        currentUser: UserModel(
          id: user.uid,
          name: user.displayName ?? user.email?.split('@').first ?? 'User',
          email: user.email ?? '',
          role: role,
        ),
        isLoading: false,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseAuthError(e.code),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  /// Registrasi pengguna baru via Firebase Auth — **tidak** melakukan auto-login.
  ///
  /// Mengembalikan `true` jika registrasi berhasil, `false` jika gagal.
  /// Setelah berhasil, user otomatis di-sign out agar harus login manual.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      state = state.copyWith(errorMessage: 'Semua kolom harus diisi.');
      return false;
    }

    if (password != confirmPassword) {
      state = state.copyWith(errorMessage: 'Password dan konfirmasi tidak cocok.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // Set display name di Firebase Auth profile.
      await credential.user!.updateDisplayName(name);

      // Simpan data user ke RTDB: /users/{uid}/
      await _db.child('users/$uid').set({
        'email': email.trim(),
        'name': name,
        'role': 'user',
      });

      // Sign out agar user harus login manual setelah registrasi.
      await _auth.signOut();

      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseAuthError(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      );
      return false;
    }
  }

  /// Logout — sign out dari Firebase dan reset state.
  Future<void> logout() async {
    await _auth.signOut();
    state = const AuthState();
  }

  /// Hapus pesan error.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Mapping kode error Firebase Auth ke pesan user-friendly (Bahasa Indonesia).
  String _mapFirebaseAuthError(String code) {
    return switch (code) {
      'user-not-found'          => 'Akun tidak ditemukan. Periksa email Anda.',
      'wrong-password'          => 'Password salah. Silakan coba lagi.',
      'invalid-credential'      => 'Email atau password salah.',
      'invalid-email'           => 'Format email tidak valid.',
      'user-disabled'           => 'Akun ini telah dinonaktifkan.',
      'email-already-in-use'    => 'Email sudah terdaftar. Silakan login.',
      'operation-not-allowed'   => 'Metode login ini tidak diizinkan.',
      'weak-password'           => 'Password terlalu lemah. Gunakan minimal 6 karakter.',
      'too-many-requests'       => 'Terlalu banyak percobaan. Coba lagi nanti.',
      'network-request-failed'  => 'Koneksi gagal. Periksa jaringan internet Anda.',
      _                         => 'Terjadi kesalahan ($code). Silakan coba lagi.',
    };
  }
}

// ═══════════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════════

/// Provider global untuk autentikasi dengan RBAC.
///
/// Contoh penggunaan:
/// ```dart
/// final auth = ref.watch(authProvider);
/// if (auth.isAuthenticated) {
///   final user = auth.currentUser!;
///   print(user.name);        // 'Super Admin GHOST'
///   print(user.isAdmin);     // true
/// }
/// ```
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
