import '../models/models.dart';

/// Filtre la bibliothèque par texte, catégorie et couleur de balle.
/// Un filtre `null` (ou un texte vide) laisse passer tous les exercices.
List<Exercise> filterExercises(
  List<Exercise> exercises, {
  String query = '',
  int? categoryId,
  int? ballColorId,
}) {
  final text = query.trim().toLowerCase();

  return exercises.where((exercise) {
    final searchable = [
      exercise.name,
      exercise.pointsToWork,
      exercise.execution,
      ...exercise.categories.map((category) => category.nom),
    ].join(' ').toLowerCase();

    return (text.isEmpty || searchable.contains(text)) &&
        (categoryId == null ||
            exercise.categories.any((item) => item.id == categoryId)) &&
        (ballColorId == null ||
            exercise.ballColors.any((item) => item.id == ballColorId));
  }).toList();
}
