import '../models/models.dart';

/// Commentaires proposés d'office dans le formulaire « Autres heures ».
const List<String> kExtraHoursSuggestions = [
  'Championnat',
  'Tournoi',
  'Aide coach',
  'Réunion',
  'Formation',
];

/// Durée maximale d'une entrée « Autres heures » : 12h (journée de tournoi).
const int kMaxExtraHoursMinutes = 12 * 60;

/// Somme des durées, en minutes.
int extraHoursMinutes(Iterable<ExtraHours> entries) =>
    entries.fold(0, (sum, hours) => sum + hours.durationMinutes);

/// Commentaires à proposer : d'abord ceux déjà utilisés (du plus récent au
/// plus ancien), puis les suggestions par défaut, sans doublon (la casse est
/// ignorée) et au plus [max].
List<String> extraHoursCommentSuggestions(
  List<ExtraHours> history, {
  int max = 8,
}) {
  final seen = <String>{};
  final result = <String>[];
  final sorted = [...history]..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });

  for (final comment in [
    ...sorted.map((hours) => hours.comment.trim()),
    ...kExtraHoursSuggestions,
  ]) {
    if (comment.isEmpty || !seen.add(comment.toLowerCase())) continue;
    result.add(comment);
    if (result.length == max) break;
  }
  return result;
}
