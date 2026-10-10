import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/place.dart';
import '../models/review.dart';
import '../services/place_service.dart';
import '../widgets/rating_widgets.dart';

class ReviewFormScreen extends StatefulWidget {
  final String gid;
  final String pid;

  /// Si viene, se edita esa reseña en lugar de crear una nueva.
  final String? reviewId;

  const ReviewFormScreen({
    super.key,
    required this.gid,
    required this.pid,
    this.reviewId,
  });

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  Place? _place;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final Map<String, int> _stars = {};
  final Map<String, TextEditingController> _comments = {};
  final _general = TextEditingController();
  DateTime _visit = DateTime.now();

  bool get _editing => widget.reviewId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    _general.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(String key) =>
      _comments.putIfAbsent(key, () => TextEditingController());

  Future<void> _load() async {
    try {
      final p = await PlaceService.instance.getPlace(widget.gid, widget.pid);

      if (_editing) {
        final existing = await PlaceService.instance.getReview(widget.gid, widget.reviewId!);
        final uid = FirebaseAuth.instance.currentUser!.uid;
        if (existing == null || existing.authorId != uid) {
          if (!mounted) return;
          setState(() {
            _place = null;
            _error = 'Solo puedes editar tus propias reseñas.';
            _loading = false;
          });
          return;
        }
        _prefill(existing);
      }

      if (!mounted) return;
      setState(() {
        _place = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el lugar: $e';
        _loading = false;
      });
    }
  }

  void _prefill(Review r) {
    r.ratings.forEach((key, rating) {
      _stars[key] = rating.stars;
      _ctrl(key).text = rating.comment ?? '';
    });
    _general.text = r.comment ?? '';
    _visit = r.visitDate ?? r.createdAt ?? DateTime.now();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visit,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _visit = picked);
  }

  Future<void> _save() async {
    if (_stars.isEmpty) {
      setState(() => _error = 'Califica al menos un punto con estrellas.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final ratings = <String, CategoryRating>{};
    for (final c in _place!.type.categories) {
      final stars = _stars[c.key];
      if (stars == null) continue;
      final text = _ctrl(c.key).text.trim();
      ratings[c.key] = CategoryRating(stars: stars, comment: text.isEmpty ? null : text);
    }

    try {
      if (_editing) {
        await PlaceService.instance.updateReview(
          widget.gid,
          widget.reviewId!,
          ratings: ratings,
          comment: _general.text,
          visitDate: _visit,
        );
      } else {
        await PlaceService.instance.addReview(
          widget.gid,
          widget.pid,
          ratings: ratings,
          comment: _general.text,
          visitDate: _visit,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar la reseña: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final place = _place;
    if (place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Lugar no encontrado.')),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_editing ? 'Editar reseña' : 'Reseña'} · ${place.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Califica solo lo que quieras: los puntos sin estrellas no cuentan en el promedio.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final c in place.type.categories)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.label, style: theme.textTheme.titleSmall),
                              if (c.hint != null) Text(c.hint!, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        StarRating(
                          value: _stars[c.key],
                          onChanged: (v) => setState(() {
                            if (v == null) {
                              _stars.remove(c.key);
                            } else {
                              _stars[c.key] = v;
                            }
                          }),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _ctrl(c.key),
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Comentario (opcional)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _general,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Comentario general (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Fecha de la visita'),
            trailing: TextButton(onPressed: _pickDate, child: Text(formatDate(_visit))),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando...' : (_editing ? 'Guardar cambios' : 'Publicar reseña')),
          ),
        ],
      ),
    );
  }
}