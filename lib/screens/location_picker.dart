import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../widgets/map_layers.dart';

/// Pantalla para elegir el punto de un lugar: buscar por nombre, pegar un enlace
/// de Google Maps o coordenadas, usar mi ubicación, o tocar el mapa.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String initialQuery;

  const LocationPickerScreen({super.key, this.initial, this.initialQuery = ''});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);

  LatLng? _point;
  String? _address;
  List<PickedLocation> _results = [];
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  void dispose() {
    _query.dispose();
    _map.dispose();
    super.dispose();
  }

  void _select(LatLng p, {String? address, bool move = true}) {
    setState(() {
      _point = p;
      _address = address;
      _results = [];
      _message = null;
    });
    if (move) _map.move(p, 16);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;

    // ¿Es un enlace de Google Maps o unas coordenadas?
    final parsed = LocationService.parseLatLng(q);
    if (parsed != null) {
      _select(parsed);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _results = [];
    });
    try {
      final r = await LocationService.search(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        if (r.isEmpty) {
          _message = 'No se encontró nada. Prueba con otro nombre o toca el mapa para marcar el punto.';
        }
      });
    } on LocationException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'No se pudo buscar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useMyLocation() async {
    try {
      final p = await LocationService.currentLatLng();
      if (mounted) _select(p);
    } on LocationException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'No se pudo obtener tu ubicación.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación del lugar')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: point ?? const LatLng(9.75, -84.0), // centro de Costa Rica
              initialZoom: point != null ? 16 : 7,
              onTap: (_, p) => _select(p, move: false),
            ),
            children: [
              osmTileLayer(),
              if (point != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, size: 48, color: Colors.red.shade600),
                    ),
                  ],
                ),
              osmAttribution(),
            ],
          ),

          // Buscador
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _query,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(),
                            decoration: const InputDecoration(
                              hintText: 'Buscar, pegar enlace de Maps o coordenadas',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        _busy
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Buscar',
                                icon: const Icon(Icons.search),
                                onPressed: _search,
                              ),
                      ],
                    ),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Text(_message!, style: theme.textTheme.bodySmall),
                    ),
                  if (_results.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final r in _results)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(r.address ?? 'Sin nombre',
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _select(r.point, address: r.address),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Usar mi ubicación
          Positioned(
            right: 12,
            bottom: 130,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Usar mi ubicación',
              onPressed: _useMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Confirmar
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      point == null
                          ? 'Toca el mapa para marcar el lugar, o búscalo arriba.'
                          : (_address ??
                              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: point == null
                          ? null
                          : () => Navigator.pop(context, PickedLocation(point, _address)),
                      child: const Text('Confirmar ubicación'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}