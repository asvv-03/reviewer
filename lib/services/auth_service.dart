import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Nombre para mostrar a los demás miembros del grupo.
  String get displayName {
    final u = _auth.currentUser;
    if (u == null) return 'Sin nombre';
    if (u.displayName != null && u.displayName!.trim().isNotEmpty) {
      return u.displayName!.trim();
    }
    return (u.email ?? 'Sin nombre').split('@').first;
  }

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.sendEmailVerification();
  }

  Future<void> resendVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Recarga el usuario y fuerza un token nuevo (para que email_verified se actualice en las reglas).
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true);
  }

  Future<void> signOut() => _auth.signOut();
}