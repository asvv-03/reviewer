import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/review.dart';
import '../services/location_service.dart';
import '../services/place_service.dart';
import '../widgets/map_layers.dart';
import '../widgets/rating_widgets.dart';

class GroupMapScreen extends StatefulWidget {
  final String gid;
  const GroupMapScreen({super.key, required this.gid});

  @override
  State<GroupMapScreen> createState() => _GroupMapScreenState();
}

class _GroupMapScreenState extends State<GroupMapScreen> {
  static const _distance = Distance();

  final _map = MapController();
  Place? _selected;
  LatLng? _me;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _locate({bool move = true}) async {
    try {
      final p = await LocationService.currentLatLng();
      if (!mounted) return false;
      setState(() => _me = p);
      if (move) _map.move(p, 14);
      return true;
    } on LocationException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('No se pudo obtener tu ubicación.');
    }
    return false;
  }

  Future<void> _showNearest(List<Place> withLoc, Map<String, ReviewSummary> sums) async {
    if (withLoc.isEmpty) {
      _snack('Ningún lugar tiene ubicación todavía.');
      return;
    }
    if (_me == null && !await _locate(move: false)) return;
    if (!mounted) return;

    final me = _me!;
    final sorted = [...withLoc]
      ..sort((a, b) => _distance
          .distance(me, a.location!)
          .compareTo(_distance.distance(me, b.location!)));

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Más cercanos a ti', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final p in sorted)
              ListTile(
                leading: CircleAvatar(child: Icon(p.type.icon)),
                title: Text(p.name),
                subtitle: Text(
                  '${LocationService.formatDistance(_distance.distance(me, p.location!))} · ${p.type.label}',
                ),
                trailing: AverageBadge(average: sums[p.id]?.average),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selected = p);
                  _map.move(p.location!, 16);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Place>>(
      stream: PlaceService.instance.watchPlaces(widget.gid),
      builder: (context, placesSnap) => StreamBuilder<List<Review>>(
        stream: PlaceService.instance.watchReviews(widget.gid),
        builder: (context, reviewsSnap) {
          if (placesSnap.hasError || reviewsSnap.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('No se pudo cargar el mapa.')),
            );
          }
          if (!placesSnap.hasData || !reviewsSnap.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Mapa')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final byPlace = <String, List<Review>>{};
          for (final r in reviewsSnap.data!) {
            byPlace.putIfAbsent(r.placeId, () => []).add(r);
          }
          final sums = {
            for (final e in byPlace.entries) e.key: ReviewSummary.from(e.value),
          };

          final withLoc = placesSnap.data!.where((p) => p.location != null).toList();
          final points = withLoc.map((p) => p.location!).toList();
          final missing = placesSnap.data!.length - withLoc.length;
          final selected = _selected;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Mapa'),
              actions: [
                IconButton(
                  tooltip: 'Más cercanos',
                  icon: const Icon(Icons.near_me),
                  onPressed: () => _showNearest(withLoc, sums),
                ),
              ],
            ),
            body: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: points.isNotEmpty ? points.first : const LatLng(9.75, -84.0),
                    initialZoom: points.isNotEmpty ? 15 : 7,
                    initialCameraFit: points.length >= 2
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(points),
                            padding: const EdgeInsets.all(56),
                            maxZoom: 16,
                          )
                        : null,
                    onTap: (_, _) => setState(() => _selected = null),
                  ),
                  children: [
                    osmTileLayer(),
                    MarkerLayer(
                      markers: [
                        for (final p in withLoc)
                          Marker(
                            point: p.location!,
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = p),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected?.id == p.id
                                      ? Colors.red.shade600
                                      : Theme.of(context).colorScheme.primary,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                                ),
                                child: Icon(p.type.icon, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_me != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _me!,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    osmAttribution(),
                  ],
                ),

                if (withLoc.isEmpty)
                  const Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Ningún lugar tiene ubicación todavía. '
                          'Agrégala al crear un lugar o desde su pantalla.',
                        ),
                      ),
                    ),
                  )
                else if (missing > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Chip(label: Text('$missing sin ubicación')),
                  ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Mi ubicación',
                    onPressed: _locate,
                    child: const Icon(Icons.my_location),
                  ),
                ),

                if (selected != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _SelectedCard(
                      place: selected,
                      summary: sums[selected.id] ?? ReviewSummary.from(<Review>[]),
                      distance: _me != null
                          ? _distance.distance(_me!, selected.location!)
                          : null,
                      onOpen: () =>
                          context.push('/group/${widget.gid}/place/${selected.id}'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  final Place place;
  final ReviewSummary summary;
  final double? distance;
  final VoidCallback onOpen;

  const _SelectedCard({
    required this.place,
    required this.summary,
    required this.distance,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      place.type.label,
      if (distance != null) LocationService.formatDistance(distance!),
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(child: Icon(place.type.icon)),
              title: Text(place.name),
              subtitle: Text(subtitle),
              trailing: AverageBadge(average: summary.average, count: summary.count),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onOpen, child: const Text('Ver reseñas')),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Cómo llegar'),
                  onPressed: () => openUrl(LocationService.directionsUrl(place.location!)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}