import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Resultado de elegir una ubicación en el mapa.
class PickedLocation {
  final LatLng point;
  final String? address;
  const PickedLocation(this.point, [this.address]);
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  LocationService._();

  /// Ubicación actual del dispositivo (GPS en móvil, permiso del navegador en web).
  static Future<LatLng> currentLatLng() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw LocationException('La ubicación del dispositivo está desactivada.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationException(
        'No hay permiso de ubicación. Actívalo en la configuración del navegador o del teléfono.',
      );
    }

    final pos = await Geolocator.getCurrentPosition();
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Búsqueda con Nominatim (OpenStreetMap). Solo se llama al enviar la búsqueda:
  /// su política de uso pide máximo 1 petición por segundo y no autocompletar.
  static Future<List<PickedLocation>> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '5',
      'accept-language': 'es',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw LocationException('La búsqueda no está disponible ahora. Intenta de nuevo en un momento.');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return PickedLocation(
        LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String)),
        m['display_name'] as String?,
      );
    }).toList();
  }

  /// Extrae coordenadas de un texto: "9.93, -84.08", o un enlace largo de Google Maps.
  /// (Los enlaces cortos tipo maps.app.goo.gl no se pueden leer desde el navegador.)
  static LatLng? parseLatLng(String input) {
    final text = input.trim();
    final patterns = [
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'), // pin exacto del lugar
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'), // centro de la vista
      RegExp(r'[?&](?:q|query|ll|destination)=(-?\d+(?:\.\d+)?)(?:,|%2C)(-?\d+(?:\.\d+)?)'),
      RegExp(r'^(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)$'), // "lat, lng"
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m == null) continue;
      final lat = double.parse(m.group(1)!);
      final lng = double.parse(m.group(2)!);
      if (lat.abs() <= 90 && lng.abs() <= 180) return LatLng(lat, lng);
    }
    return null;
  }

  /// Abre Google Maps con la ruta hacia el lugar (no requiere clave de API).
  static String directionsUrl(LatLng p) =>
      'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}';

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}