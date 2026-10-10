import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // Si todo sale bien, el router redirige solo al detectar la sesión.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return null; // el usuario cerró la ventana, no es un error
      default:
        return e.message ?? e.code;
    }
  }

  void _submit() {
    if (_register) {
      if (_name.text.trim().isEmpty) {
        setState(() => _error = 'Escribe tu nombre.');
        return;
      }
      _run(() => AuthService.instance.register(_name.text, _email.text, _pass.text));
    } else {
      _run(() => AuthService.instance.signInWithEmail(_email.text, _pass.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.restaurant_menu, size: 56, color: scheme.primary),
                const SizedBox(height: 8),
                Text('Reseñas en familia',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Tu nombre'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_register ? 'Crear cuenta' : 'Iniciar sesión'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _register = !_register),
                  child: Text(_register
                      ? 'Ya tengo cuenta'
                      : '¿No tienes cuenta? Regístrate'),
                ),
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(AuthService.instance.signInWithGoogle),
                  icon: const Icon(Icons.login),
                  label: const Text('Continuar con Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}