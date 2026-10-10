import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/group_service.dart';

Future<void> showInviteDialog(BuildContext context, String gid, String groupName) async {
  final emailCtrl = TextEditingController();
  String? link;
  String? error;
  bool busy = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Invitar a la familia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (link == null) ...[
              const Text(
                'Escribe un correo para que solo esa persona pueda usar el enlace, '
                'o déjalo vacío para un enlace abierto.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo (opcional)'),
              ),
            ] else ...[
              const Text('Comparte este enlace (vence en 7 días):'),
              const SizedBox(height: 8),
              SelectableText(link!),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          if (link == null)
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final l = await GroupService.instance.createInvite(
                          groupId: gid,
                          groupName: groupName,
                          email: emailCtrl.text,
                        );
                        setState(() => link = l);
                      } catch (e) {
                        setState(() => error = 'No se pudo crear la invitación: $e');
                      } finally {
                        setState(() => busy = false);
                      }
                    },
              child: const Text('Crear enlace'),
            )
          else
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link!));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(const SnackBar(content: Text('Enlace copiado')));
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
        ],
      ),
    ),
  );
  emailCtrl.dispose();
}