import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/rating_categories.dart';
import '../models/review.dart';
import 'auth_service.dart';

class PlaceService {
  PlaceService._();
  static final instance = PlaceService._();

  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _places(String gid) =>
      _db.collection('groups').doc(gid).collection('places');

  CollectionReference<Map<String, dynamic>> _reviews(String gid) =>
      _db.collection('groups').doc(gid).collection('reviews');

  // ---------- Lugares ----------

  Stream<List<Place>> watchPlaces(String gid) {
    return _places(gid).snapshots().map((s) {
      final list = s.docs.map(Place.fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Stream<Place?> watchPlace(String gid, String pid) {
    return _places(gid).doc(pid).snapshots().map((d) => d.exists ? Place.fromDoc(d) : null);
  }

  Future<Place?> getPlace(String gid, String pid) async {
    final d = await _places(gid).doc(pid).get();
    return d.exists ? Place.fromDoc(d) : null;
  }

  Future<String> addPlace(
    String gid, {
    required String name,
    required PlaceType type,
    String city = '',
    LatLng? location,
    String? address,
  }) async {
    final ref = await _places(gid).add({
      'name': name.trim(),
      'type': type.value,
      'city': city.trim(),
      if (location != null) 'lat': location.latitude,
      if (location != null) 'lng': location.longitude,
      if (location != null && address != null && address.isNotEmpty) 'address': address,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateLocation(String gid, String pid, LatLng location, String? address) {
    return _places(gid).doc(pid).update({
      'lat': location.latitude,
      'lng': location.longitude,
      'address': (address != null && address.isNotEmpty) ? address : FieldValue.delete(),
    });
  }

  // ---------- Reseñas ----------

  List<Review> _sorted(List<Review> list) {
    list.sort((a, b) {
      final ta = a.createdAt ?? DateTime.now(); // aún sin confirmar por el servidor
      final tb = b.createdAt ?? DateTime.now();
      return tb.compareTo(ta);
    });
    return list;
  }

  Stream<List<Review>> watchReviews(String gid) {
    return _reviews(gid).snapshots().map((s) => _sorted(s.docs.map(Review.fromDoc).toList()));
  }

  Stream<List<Review>> watchPlaceReviews(String gid, String pid) {
    return _reviews(gid)
        .where('placeId', isEqualTo: pid)
        .snapshots()
        .map((s) => _sorted(s.docs.map(Review.fromDoc).toList()));
  }

  Future<void> addReview(
    String gid,
    String pid, {
    required Map<String, CategoryRating> ratings,
    String? comment,
    required DateTime visitDate,
  }) async {
    await _reviews(gid).add({
      'placeId': pid,
      'authorId': _uid,
      'authorName': AuthService.instance.displayName,
      'ratings': {for (final e in ratings.entries) e.key: e.value.toMap()},
      'average': Review.computeAverage(ratings),
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      'visitDate': Timestamp.fromDate(visitDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Review?> getReview(String gid, String rid) async {
    final d = await _reviews(gid).doc(rid).get();
    return d.exists ? Review.fromDoc(d) : null;
  }

  /// Actualiza solo lo editable; autor, lugar y fecha de creación no cambian.
  Future<void> updateReview(
    String gid,
    String rid, {
    required Map<String, CategoryRating> ratings,
    String? comment,
    required DateTime visitDate,
  }) async {
    final hasComment = comment != null && comment.trim().isNotEmpty;
    await _reviews(gid).doc(rid).update({
      'ratings': {for (final e in ratings.entries) e.key: e.value.toMap()},
      'average': Review.computeAverage(ratings),
      'comment': hasComment ? comment.trim() : FieldValue.delete(),
      'visitDate': Timestamp.fromDate(visitDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReview(String gid, String rid) => _reviews(gid).doc(rid).delete();
}