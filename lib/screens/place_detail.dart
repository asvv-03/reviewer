import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/place.dart';
import '../models/rating_categories.dart';
import '../models/review.dart';
import '../services/place_service.dart';
import '../widgets/rating_widgets.dart';

import '../widgets/place_location_card.dart';

class PlaceDetailScreen extends StatelessWidget {
  final String gid;
  final String pid;
  const PlaceDetailScreen({super.key, required this.gid, required this.pid});

  Future<void> _delete(BuildContext context, Review r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu reseña?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await PlaceService.instance.deleteReview(gid, r.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<Place?>(
      stream: PlaceService.instance.watchPlace(gid, pid),
      builder: (context, placeSnap) {
        if (placeSnap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('No tienes acceso a este lugar.')),
          );
        }
        final place = placeSnap.data;
        if (place == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: placeSnap.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : const Text('Lugar no encontrado.'),
            ),
          );
        }

        return StreamBuilder<List<Review>>(
          stream: PlaceService.instance.watchPlaceReviews(gid, pid),
          builder: (context, reviewsSnap) {
            final reviews = reviewsSnap.data ?? <Review>[];
            final summary = ReviewSummary.from(reviews);
            final theme = Theme.of(context);

            return Scaffold(
              appBar: AppBar(title: Text(place.name)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => context.push('/group/$gid/place/$pid/review'),
                icon: const Icon(Icons.rate_review),
                label: const Text('Escribir reseña'),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Row(
                    children: [
                      Icon(place.type.icon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [place.type.label, if (place.city.isNotEmpty) place.city].join(' · '),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      AverageBadge(average: summary.average, count: summary.count, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (summary.count > 0)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Promedio por punto', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            for (final c in place.type.categories)
                              if (summary.byCategory[c.key] != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(c.label)),
                                      AverageBadge(average: summary.byCategory[c.key]),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  PlaceLocationCard(gid: gid, place: place, canEdit: place.createdBy == uid),
                  const SizedBox(height: 16),
                  Text('Reseñas (${reviews.length})', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Todavía nadie ha reseñado este lugar.')),
                    ),
                  for (final r in reviews)
                    _ReviewCard(
                      review: r,
                      type: place.type,
                      canDelete: r.authorId == uid,
                      onDelete: () => _delete(context, r),
                      onEdit: () => context.push('/group/$gid/place/$pid/review?edit=${r.id}'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final PlaceType type;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ReviewCard({
    required this.review,
    required this.type,
    required this.canDelete,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = review.visitDate ?? review.createdAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.authorName + (date != null ? ' · ${formatDate(date)}' : ''),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                AverageBadge(average: review.average),
                if (canDelete) ...[
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            if (review.comment != null) ...[
              const SizedBox(height: 4),
              Text(review.comment!),
            ],
            const Divider(),
            for (final c in type.categories)
              if (review.ratings[c.key] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(c.label)),
                          StarRating(value: review.ratings[c.key]!.stars, size: 18),
                        ],
                      ),
                      if (review.ratings[c.key]!.comment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            review.ratings[c.key]!.comment!,
                            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}