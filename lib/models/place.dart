import 'package:cloud_firestore/cloud_firestore.dart';

import 'rating_categories.dart';

class Place {
  final String id;
  final String name;
  final PlaceType type;
  final String city;
  final String createdBy;

  Place({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.createdBy,
  });

  factory Place.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return Place(
      id: d.id,
      name: data['name'] as String? ?? '',
      type: PlaceType.parse(data['type'] as String?),
      city: data['city'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}