/// Lundi à 00:00 de la semaine contenant [date].
///
/// La semaine commence le lundi, comme le calendrier de l'application.
DateTime startOfWeek(DateTime date) => DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - DateTime.monday),
    );

/// Lundi suivant à 00:00 (borne exclue).
DateTime endOfWeekExclusive(DateTime date) {
  final start = startOfWeek(date);
  return DateTime(start.year, start.month, start.day + 7);
}

/// Vrai si [date] tombe dans la même semaine (lundi → dimanche) que
/// [reference].
bool isInSameWeek(DateTime date, DateTime reference) {
  final day = DateTime(date.year, date.month, date.day);
  return !day.isBefore(startOfWeek(reference)) &&
      day.isBefore(endOfWeekExclusive(reference));
}

/// Vrai si [date] et [reference] sont dans le même mois civil.
bool isInSameMonth(DateTime date, DateTime reference) =>
    date.year == reference.year && date.month == reference.month;
