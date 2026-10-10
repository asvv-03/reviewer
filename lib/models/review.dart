import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryRating {
  final int stars;
  final String? comment;
  const CategoryRating({required this.stars, this.comment});

  Map<String, dynamic> toMap() => {
        'stars': stars,
        if (comment != null) 'comment': comment,
      };
}

class Review {
  final String id;
  final String placeId;
  final String authorId;
  final String authorName;
  final Map<String, CategoryRating> ratings;
  final double average;
  final String? comment;
  final DateTime? visitDate;
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.placeId,
    required this.authorId,
    required this.authorName,
    required this.ratings,
    required this.average,
    this.comment,
    this.visitDate,
    this.createdAt,
  });

  /// Promedio solo de los puntos que se calificaron.
  static double computeAverage(Map<String, CategoryRating> ratings) {
    if (ratings.isEmpty) return 0;
    final sum = ratings.values.fold<int>(0, (a, r) => a + r.stars);
    return sum / ratings.length;
  }

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final raw = (data['ratings'] as Map<String, dynamic>?) ?? {};
    final ratings = raw.map((key, value) {
      final m = value as Map<String, dynamic>;
      return MapEntry(
        key,
        CategoryRating(stars: (m['stars'] as num).toInt(), comment: m['comment'] as String?),
      );
    });
    return Review(
      id: d.id,
      placeId: data['placeId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Sin nombre',
      ratings: ratings,
      average: (data['average'] as num?)?.toDouble() ?? computeAverage(ratings),
      comment: data['comment'] as String?,
      visitDate: (data['visitDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Resumen de todas las reseñas de un lugar.
class ReviewSummary {
  final int count;
  final double? average;
  final Map<String, double> byCategory;

  ReviewSummary({required this.count, required this.average, required this.byCategory});

  factory ReviewSummary.from(List<Review> reviews) {
    if (reviews.isEmpty) {
      return ReviewSummary(count: 0, average: null, byCategory: {});
    }
    final avg = reviews.fold<double>(0, (a, r) => a + r.average) / reviews.length;

    final sums = <String, int>{};
    final counts = <String, int>{};
    for (final r in reviews) {
      r.ratings.forEach((key, rating) {
        sums[key] = (sums[key] ?? 0) + rating.stars;
        counts[key] = (counts[key] ?? 0) + 1;
      });
    }
    final byCategory = {for (final k in sums.keys) k: sums[k]! / counts[k]!};
    return ReviewSummary(count: reviews.length, average: avg, byCategory: byCategory);
  }
}