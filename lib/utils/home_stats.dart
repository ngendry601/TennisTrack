import '../models/models.dart';
import 'formatters.dart';

/// Temps passé sur une catégorie pendant une période.
class CategoryShare {
  const CategoryShare({
    required this.name,
    required this.minutes,
    required this.percent,
  });

  final String name;
  final int minutes;

  /// Part du temps total de la période, de 0 à 100.
  final int percent;
}

/// Catégories triées de la plus travaillée à la moins travaillée.
///
/// Une séance avec plusieurs catégories compte entièrement dans chacune :
/// la somme des pourcentages peut donc dépasser 100.
List<CategoryShare> categoryShares(List<TrainingSession> sessions) {
  final total =
      sessions.fold<int>(0, (sum, session) => sum + session.totalMinutes);
  if (total == 0) return const [];

  final minutesByName = <String, int>{};
  for (final session in sessions) {
    final names = session.categories.isEmpty
        ? const ['Sans catégorie']
        : session.categories.map((category) => category.nom);
    for (final name in names) {
      minutesByName[name] = (minutesByName[name] ?? 0) + session.totalMinutes;
    }
  }

  final shares = minutesByName.entries
      .map((entry) => CategoryShare(
            name: entry.key,
            minutes: entry.value,
            percent: (entry.value * 100 / total).round(),
          ))
      .toList()
    ..sort((a, b) {
      final byMinutes = b.minutes.compareTo(a.minutes);
      return byMinutes != 0 ? byMinutes : a.name.compareTo(b.name);
    });
  return shares;
}

/// Séances du dernier jour joué jusqu'au jour de [reference] inclus, dans
/// l'ordre de la journée (séances sans heure en premier). Les séances datées
/// dans le futur sont ignorées. Liste vide s'il n'y a aucune séance passée.
List<TrainingSession> latestSessionDay(
  List<TrainingSession> sessions,
  DateTime reference,
) {
  final lastDay = DateTime(reference.year, reference.month, reference.day);
  DateTime? latest;

  for (final session in sessions) {
    final day = _day(session.date);
    if (day.isAfter(lastDay)) continue;
    if (latest == null || day.isAfter(latest)) latest = day;
  }
  if (latest == null) return const [];

  return sessions.where((session) => _day(session.date) == latest).toList()
    ..sort((a, b) => _isAfter(a, b) ? 1 : -1);
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isAfter(TrainingSession a, TrainingSession b) {
  final dayA = DateTime(a.date.year, a.date.month, a.date.day);
  final dayB = DateTime(b.date.year, b.date.month, b.date.day);
  if (dayA != dayB) return dayA.isAfter(dayB);

  final startA = a.startTime;
  final startB = b.startTime;
  final minutesA = startA == null ? -1 : startA.hour * 60 + startA.minute;
  final minutesB = startB == null ? -1 : startB.hour * 60 + startB.minute;
  if (minutesA != minutesB) return minutesA > minutesB;
  return a.id > b.id;
}

/// « +2h30min par rapport à octobre », « -1h par rapport à octobre »
/// ou « Autant d'heures qu'en octobre ».
String formatMonthComparison({
  required int currentMinutes,
  required int previousMinutes,
  required String previousMonthName,
}) {
  final delta = currentMinutes - previousMinutes;
  if (delta == 0) return "Autant d'heures qu'en $previousMonthName";
  final sign = delta > 0 ? '+' : '-';
  return '$sign${formatDuration(delta.abs())} '
      'par rapport à $previousMonthName';
}
