import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/rating_categories.dart';
import '../services/place_service.dart';

/// Pide nombre, tipo y ciudad; crea el lugar y abre su pantalla.
Future<void> showAddPlaceDialog(BuildContext context, String gid) async {
  final nameCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  PlaceType type = PlaceType.restaurant;
  String? error;
  bool busy = false;

  final newId = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Agregar lugar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<PlaceType>(
                segments: [
                  for (final t in PlaceType.values)
                    ButtonSegment(value: t, label: Text(t.label), icon: Icon(t.icon)),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ciudad o zona (opcional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      setState(() => error = 'Escribe el nombre del lugar.');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final id = await PlaceService.instance.addPlace(
                        gid,
                        name: nameCtrl.text,
                        type: type,
                        city: cityCtrl.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, id);
                    } catch (e) {
                      setState(() {
                        busy = false;
                        error = 'No se pudo guardar: $e';
                      });
                    }
                  },
            child: const Text('Agregar'),
          ),
        ],
      ),
    ),
  );

  nameCtrl.dispose();
  cityCtrl.dispose();
  if (newId != null && context.mounted) context.push('/group/$gid/place/$newId');
}