import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/place.dart';
import '../screens/location_picker.dart';
import '../services/location_service.dart';
import '../services/place_service.dart';
import 'map_layers.dart';

class PlaceLocationCard extends StatelessWidget {
  final String gid;
  final Place place;

  /// Solo quien creó el lugar (o un admin) puede cambiar la ubicación, según las reglas.
  final bool canEdit;

  const PlaceLocationCard({
    super.key,
    required this.gid,
    required this.place,
    required this.canEdit,
  });

  Future<void> _edit(BuildContext context) async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: place.location,
          initialQuery: [place.name, place.city].where((s) => s.trim().isNotEmpty).join(', '),
        ),
      ),
    );
    if (picked == null) return;
    try {
      await PlaceService.instance.updateLocation(gid, place.id, picked.point, picked.address);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la ubicación: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = place.location;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loc != null)
            SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: loc,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  osmTileLayer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: loc,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: Icon(Icons.location_on, size: 44, color: Colors.red.shade600),
                      ),
                    ],
                  ),
                  osmAttribution(),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(
              loc == null ? 'Sin ubicación en el mapa' : (place.address ?? 'Ubicación guardada'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (loc != null)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.directions),
                    label: const Text('Cómo llegar'),
                    onPressed: () => openUrl(LocationService.directionsUrl(loc)),
                  ),
                if (canEdit)
                  TextButton.icon(
                    icon: Icon(loc == null ? Icons.add_location_alt_outlined : Icons.edit_location_alt_outlined),
                    label: Text(loc == null ? 'Agregar ubicación' : 'Cambiar'),
                    onPressed: () => _edit(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}