import '../models/models.dart';
import 'formatters.dart';

/// Durée maximale d'un exercice, en minutes (4h, comme une séance).
const int kMaxExerciseMinutes = 240;

/// Somme des durées renseignées des exercices, en minutes.
/// Les exercices sans durée ne comptent pas.
int exercisesTotalMinutes(List<Exercise> exercises) =>
    exercises.fold(0, (sum, exercise) => sum + (exercise.durationMinutes ?? 0));

/// Total des exercices comparé à la durée de la séance, par exemple
/// « Exercices : 1h10min sur 1h30min ».
///
/// Précise quand le total dépasse la séance et combien d'exercices n'ont pas
/// de durée. Renvoie `null` quand aucun exercice n'a de durée : il n'y a
/// alors rien d'utile à afficher.
String? exercisesTotalLabel(List<Exercise> exercises, int sessionMinutes) {
  if (exercises.every((exercise) => exercise.durationMinutes == null)) {
    return null;
  }

  final total = exercisesTotalMinutes(exercises);
  final missing =
      exercises.where((exercise) => exercise.durationMinutes == null).length;

  final parts = [
    'Exercices : ${formatDuration(total)} sur ${formatDuration(sessionMinutes)}',
    if (total > sessionMinutes)
      'dépasse de ${formatDuration(total - sessionMinutes)}',
    if (missing > 0) '$missing sans durée',
  ];
  return parts.join(' · ');
}
