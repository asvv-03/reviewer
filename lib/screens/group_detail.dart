import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/group.dart';
import '../models/place.dart';
import '../models/rating_categories.dart';
import '../models/review.dart';
import '../services/group_service.dart';
import '../services/place_service.dart';
import '../widgets/rating_widgets.dart';
import 'add_place_dialog.dart';
import 'invite_dialog.dart';

class GroupDetailScreen extends StatelessWidget {
  final String gid;
  const GroupDetailScreen({super.key, required this.gid});

  Future<void> _leave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del grupo?'),
        content: const Text('Dejarás de ver las reseñas de este grupo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    if (ok != true) return;
    await GroupService.instance.leaveGroup(gid);
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('groups').doc(gid).snapshots(),
      builder: (context, groupSnap) {
        if (groupSnap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('No tienes acceso a este grupo.')),
          );
        }
        final groupName = groupSnap.data?.data()?['name'] as String? ?? '...';

        return StreamBuilder<List<Member>>(
          stream: GroupService.instance.watchMembers(gid),
          builder: (context, snap) {
            final members = snap.data ?? [];
            final isAdmin = members.any((m) => m.uid == uid && m.isAdmin);

            return Scaffold(
              appBar: AppBar(
                title: Text(groupName),
                actions: [
                  IconButton(
                    tooltip: 'Mapa',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => context.push('/group/$gid/map'),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: 'Invitar',
                      icon: const Icon(Icons.person_add),
                      onPressed: () => showInviteDialog(context, gid, groupName),
                    ),
                  IconButton(
                    tooltip: 'Salir del grupo',
                    icon: const Icon(Icons.exit_to_app),
                    onPressed: () => _leave(context),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => showAddPlaceDialog(context, gid),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Agregar lugar'),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _PlacesSection(gid: gid),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: Text('Miembros (${members.length})'),
                    children: [
                      for (final m in members)
                        ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              m.displayName.isEmpty ? '?' : m.displayName[0].toUpperCase(),
                            ),
                          ),
                          title: Text(m.displayName + (m.uid == uid ? ' (tú)' : '')),
                          trailing: m.isAdmin ? const Chip(label: Text('Admin')) : null,
                        ),
                    ],
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

class _PlacesSection extends StatefulWidget {
  final String gid;
  const _PlacesSection({required this.gid});

  @override
  State<_PlacesSection> createState() => _PlacesSectionState();
}

class _PlacesSectionState extends State<_PlacesSection> {
  PlaceType? _filter; // null = todos

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Place>>(
      stream: PlaceService.instance.watchPlaces(widget.gid),
      builder: (context, placesSnap) {
        return StreamBuilder<List<Review>>(
          stream: PlaceService.instance.watchReviews(widget.gid),
          builder: (context, reviewsSnap) {
            if (placesSnap.hasError || reviewsSnap.hasError) {
              return const Text('No se pudieron cargar los lugares.');
            }
            if (!placesSnap.hasData || !reviewsSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final byPlace = <String, List<Review>>{};
            for (final r in reviewsSnap.data!) {
              byPlace.putIfAbsent(r.placeId, () => []).add(r);
            }
            final places = placesSnap.data!
                .where((p) => _filter == null || p.type == _filter)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final t in PlaceType.values)
                      ChoiceChip(
                        avatar: Icon(t.icon, size: 18),
                        label: Text('${t.label}s'),
                        selected: _filter == t,
                        onSelected: (_) => setState(() => _filter = t),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (places.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aún no hay lugares.\nAgrega el primero con el botón de abajo.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  for (final p in places)
                    _PlaceTile(
                      place: p,
                      summary: ReviewSummary.from(byPlace[p.id] ?? []),
                      onTap: () => context.push('/group/${widget.gid}/place/${p.id}'),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final Place place;
  final ReviewSummary summary;
  final VoidCallback onTap;

  const _PlaceTile({required this.place, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      place.type.label,
      if (place.city.isNotEmpty) place.city,
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(place.type.icon)),
        title: Text(place.name),
        subtitle: Text(subtitle),
        trailing: AverageBadge(average: summary.average, count: summary.count),
        onTap: onTap,
      ),
    );
  }
}