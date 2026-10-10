import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'rating_categories.dart';

class Place {
  final String id;
  final String name;
  final PlaceType type;
  final String city;
  final String createdBy;
  final LatLng? location;
  final String? address;

  Place({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.createdBy,
    this.location,
    this.address,
  });

  factory Place.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    return Place(
      id: d.id,
      name: data['name'] as String? ?? '',
      type: PlaceType.parse(data['type'] as String?),
      city: data['city'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      location: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      address: data['address'] as String?,
    );
  }
}