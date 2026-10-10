import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/group.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  Future<void> _createGroup(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo grupo familiar'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre (p. ej. Familia Pérez)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      final gid = await GroupService.instance.createGroup(name);
      if (context.mounted) context.push('/group/$gid');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo crear el grupo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: AuthService.instance.signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createGroup(context),
        icon: const Icon(Icons.group_add),
        label: const Text('Nuevo grupo'),
      ),
      body: StreamBuilder<List<Group>>(
        stream: GroupService.instance.watchMyGroups(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error al cargar: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data!;
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no perteneces a ningún grupo.\nCrea uno o abre un enlace de invitación.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final g = groups[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.family_restroom)),
                title: Text(g.name),
                subtitle: Text(g.role == 'admin' ? 'Administrador' : 'Miembro'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/group/${g.id}'),
              );
            },
          );
        },
      ),
    );
  }
}