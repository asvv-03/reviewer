import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/group.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';

class JoinScreen extends StatefulWidget {
  final String inviteId;
  const JoinScreen({super.key, required this.inviteId});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  Invite? _invite;
  bool _loading = true;
  bool _alreadyMember = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final inv = await GroupService.instance.getInvite(widget.inviteId);
      final member = inv != null && await GroupService.instance.isMember(inv.groupId);
      if (!mounted) return;
      setState(() {
        _invite = inv;
        _alreadyMember = member;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la invitación: $e';
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GroupService.instance.joinGroup(_invite!);
      if (mounted) context.go('/group/${_invite!.groupId}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo unir al grupo. Revisa que la invitación sea para tu correo y no haya vencido.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshVerification() async {
    await AuthService.instance.reloadUser();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitación'),
        leading: IconButton(icon: const Icon(Icons.home), onPressed: () => context.go('/')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _content(context),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final inv = _invite;

    if (inv == null) {
      return [Text(_error ?? 'Invitación no encontrada o ya utilizada.', textAlign: TextAlign.center)];
    }
    if (inv.expired) {
      return [const Text('Esta invitación venció. Pide que te envíen una nueva.', textAlign: TextAlign.center)];
    }
    if (_alreadyMember) {
      return [
        Text('Ya perteneces a "${inv.groupName}".', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/group/${inv.groupId}'),
          child: const Text('Abrir grupo'),
        ),
      ];
    }

    final user = AuthService.instance.currentUser!;
    final userEmail = user.email?.toLowerCase();
    final title = Text(
      'Te invitaron a unirte a\n"${inv.groupName}"',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge,
    );

    // Invitación dirigida a otro correo
    if (inv.email != null && inv.email != userEmail) {
      return [
        title,
        const SizedBox(height: 16),
        Text(
          'Esta invitación es para ${inv.email}. Cierra sesión e ingresa con ese correo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: errorColor),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: AuthService.instance.signOut, child: const Text('Cerrar sesión')),
      ];
    }

    // Invitación por correo: se exige correo verificado (lo pide la regla de seguridad)
    if (inv.email != null && !user.emailVerified) {
      return [
        title,
        const SizedBox(height: 16),
        const Text(
          'Primero verifica tu correo: te enviamos un mensaje con un enlace de verificación.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _refreshVerification, child: const Text('Ya verifiqué mi correo')),
        TextButton(
          onPressed: AuthService.instance.resendVerification,
          child: const Text('Reenviar correo de verificación'),
        ),
      ];
    }

    return [
      title,
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: errorColor)),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy ? null : _join,
        child: const Text('Unirme al grupo'),
      ),
    ];
  }
}