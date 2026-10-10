import 'package:flutter/material.dart';

class RatingCategory {
  final String key;
  final String label;
  final String? hint;
  const RatingCategory(this.key, this.label, [this.hint]);
}

enum PlaceType {
  restaurant('restaurant', 'Restaurante', Icons.restaurant, [
    RatingCategory('drink', 'Bebida'),
    RatingCategory('food', 'Comida'),
    RatingCategory('wait', 'Tiempo de espera', '5 = muy rápido'),
    RatingCategory('service', 'Servicio'),
    RatingCategory('price', 'Precio', '5 = muy conveniente'),
  ]),
  hotel('hotel', 'Hotel', Icons.hotel, [
    RatingCategory('location', 'Ubicación'),
    RatingCategory('cleanliness', 'Limpieza'),
    RatingCategory('bathroom', 'Baño'),
    RatingCategory('beds', 'Camas'),
    RatingCategory('food', 'Comida'),
    RatingCategory('roomSize', 'Tamaño de la habitación'),
    RatingCategory('price', 'Precio', '5 = muy conveniente'),
  ]);

  const PlaceType(this.value, this.label, this.icon, this.categories);

  final String value;
  final String label;
  final IconData icon;
  final List<RatingCategory> categories;

  static PlaceType parse(String? v) => PlaceType.values.firstWhere(
        (t) => t.value == v,
        orElse: () => PlaceType.restaurant,
      );
}