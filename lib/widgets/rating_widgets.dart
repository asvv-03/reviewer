import 'package:flutter/material.dart';

/// Estrellas de 1 a 5. Si [onChanged] es null, solo muestra el valor.
/// Tocar la estrella ya seleccionada quita la calificación (null).
class StarRating extends StatelessWidget {
  final int? value;
  final ValueChanged<int?>? onChanged;
  final double size;

  const StarRating({super.key, required this.value, this.onChanged, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = value != null && i < value!;
        final icon = Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: Colors.amber.shade700,
        );
        if (onChanged == null) return icon;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged!(value == i + 1 ? null : i + 1),
          child: Padding(padding: const EdgeInsets.all(2), child: icon),
        );
      }),
    );
  }
}

/// Promedio con una estrella, p. ej. "★ 4.3 (5)".
class AverageBadge extends StatelessWidget {
  final double? average;
  final int? count;
  final double size;

  const AverageBadge({super.key, required this.average, this.count, this.size = 16});

  @override
  Widget build(BuildContext context) {
    if (average == null) {
      return Text('Sin reseñas', style: Theme.of(context).textTheme.bodySmall);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: size + 2, color: Colors.amber.shade700),
        const SizedBox(width: 4),
        Text(
          average!.toStringAsFixed(1) + (count != null ? ' ($count)' : ''),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';