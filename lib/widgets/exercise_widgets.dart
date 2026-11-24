import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

/// Deux lignes de filtres : couleur de balle, puis catégorie.
class ExerciseFilterBar extends StatelessWidget {
  const ExerciseFilterBar({
    super.key,
    required this.categories,
    required this.ballColors,
    required this.categoryId,
    required this.ballColorId,
    required this.onCategoryChanged,
    required this.onBallColorChanged,
  });

  final List<TrainingCategory> categories;
  final List<BallColor> ballColors;
  final int? categoryId;
  final int? ballColorId;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onBallColorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChipRow(
          children: [
            ChoiceChip(
              label: const Text('Toutes les balles'),
              showCheckmark: false,
              selected: ballColorId == null,
              onSelected: (_) => onBallColorChanged(null),
            ),
            for (final color in ballColors)
              ChoiceChip(
                avatar: BallDot(color: color),
                label: Text(color.nom),
                showCheckmark: false,
                selected: ballColorId == color.id,
                onSelected: (selected) =>
                    onBallColorChanged(selected ? color.id : null),
              ),
          ],
        ),
        _ChipRow(
          children: [
            ChoiceChip(
              label: const Text('Tous les thèmes'),
              showCheckmark: false,
              selected: categoryId == null,
              onSelected: (_) => onCategoryChanged(null),
            ),
            for (final category in categories)
              ChoiceChip(
                label: Text(category.nom),
                showCheckmark: false,
                selected: categoryId == category.id,
                onSelected: (selected) =>
                    onCategoryChanged(selected ? category.id : null),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(child: child),
            ),
        ],
      ),
    );
  }
}

/// Pastille de la couleur d'une balle.
class BallDot extends StatelessWidget {
  const BallDot({super.key, required this.color, this.size = 14});

  final BallColor color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Balle ${color.nom}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26, width: 0.5),
        ),
      ),
    );
  }
}

/// Image de l'exercice, ou icône s'il n'en a pas.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final image = exercise.image;
    if (image == null) {
      return const CircleAvatar(child: Icon(Icons.fitness_center));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        image,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Ligne d'infos : pastilles de balles et thèmes de l'exercice.
class ExerciseMeta extends StatelessWidget {
  const ExerciseMeta({super.key, required this.exercise, this.usage});

  final Exercise exercise;

  /// Nombre de séances utilisant l'exercice, si on veut l'afficher.
  final int? usage;

  @override
  Widget build(BuildContext context) {
    final count = usage;
    final duration = exercise.durationMinutes;
    final style = Theme.of(context).textTheme.bodySmall;

    return Row(
      children: [
        for (final color in exercise.ballColors)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: BallDot(color: color, size: 11),
          ),
        if (exercise.ballColors.isNotEmpty) const SizedBox(width: 4),
        Expanded(
          child: Text(
            exercise.categories.map((category) => category.nom).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        // Hors de la zone tronquée : durée et nombre de séances restent
        // toujours lisibles.
        if (duration != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.timer_outlined, size: 13, color: style?.color),
          const SizedBox(width: 2),
          Text(formatDuration(duration), style: style),
        ],
        if (count != null) ...[
          const SizedBox(width: 6),
          Text('$count séance${count > 1 ? 's' : ''}', style: style),
        ],
      ],
    );
  }
}
