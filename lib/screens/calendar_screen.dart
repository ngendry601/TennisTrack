import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/session_times.dart';
import '../utils/extra_hours.dart';
import '../widgets/extra_hours_tile.dart';
import 'extra_hours_form_screen.dart';
import 'session/session_detail_screen.dart';
import 'session/session_form_screen.dart';

/// Calendrier mensuel : chaque jour contenant une séance est marqué, et un
/// appui affiche les horaires, la durée totale et les thèmes du jour.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store, this.initialDate});

  final SessionStore store;

  /// Mois et jour affichés au démarrage. Par défaut : aujourd'hui.
  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// Premier jour du mois affiché.
  late DateTime _visibleMonth;

  /// Jour sélectionné (toujours à minuit).
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    // DateTime(année, mois) sans jour = le 1er du mois à minuit.
    _visibleMonth = DateTime(initial.year, initial.month);
    _selectedDay = DateTime(initial.year, initial.month, initial.day);
  }

  /// Bouton « Ajouter » du jour : propose une séance ou des heures hors
  /// séance (championnat, aide coach…), à la date sélectionnée.
  Future<void> _addOnDay(DateTime day) async {
    final extra = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sports_tennis),
              title: const Text('Une séance'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.more_time),
              title: const Text('Des heures hors séance'),
              subtitle: const Text('Championnat, aide coach…'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (extra == null || !mounted) return;
    if (extra) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ExtraHoursFormScreen(store: widget.store, initialDate: day),
      ));
    } else {
      await _openForm(date: day);
    }
  }

  Future<void> _openForm({DateTime? date}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionFormScreen(
        store: widget.store,
        initialDate: date,
      ),
    ));
  }

  void _openDetails(TrainingSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SessionDetailScreen(store: widget.store, session: session),
    ));
  }

  /// Regroupe les séances par jour et les trie par heure de début.
  // Dictionnaire « jour → séances du jour ». Les jours sont ramenés à minuit
  // pour que toutes les séances d'un même jour tombent sous la même clé.
  Map<DateTime, List<TrainingSession>> _sessionsByDay() {
    final byDay = <DateTime, List<TrainingSession>>{};
    for (final session in widget.store.sessions) {
      final day =
          DateTime(session.date.year, session.date.month, session.date.day);
      // putIfAbsent crée la liste du jour si elle n'existe pas encore.
      byDay.putIfAbsent(day, () => []).add(session);
    }
    for (final sessions in byDay.values) {
      sessions.sort((a, b) {
        final startA = a.startTime;
        final startB = b.startTime;
        if (startA == null && startB == null) return b.id.compareTo(a.id);
        // Séances sans heure de début : placées après celles qui en ont une.
        if (startA == null) return 1;
        if (startB == null) return -1;
        return (startA.hour * 60 + startA.minute)
            .compareTo(startB.hour * 60 + startB.minute);
      });
    }
    return byDay;
  }

  // Flèches mois précédent / suivant (delta = -1 ou +1). Le jour sélectionné
  // devient le premier jour du mois qui a une séance, sinon le 1er.
  // DateTime gère seul le passage d'année (mois 13 = janvier suivant).
  void _changeMonth(int delta, Map<DateTime, List<TrainingSession>> byDay) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final daysWithSessions = byDay.keys
        .where((day) => day.year == next.year && day.month == next.month)
        .toList()
      ..sort();

    setState(() {
      _visibleMonth = next;
      _selectedDay =
          daysWithSessions.isNotEmpty ? daysWithSessions.first : next;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  void _selectDay(DateTime day) => setState(() => _selectedDay = day);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final byDay = _sessionsByDay();
        // Heures hors séances regroupées par jour, comme les séances.
        final extraByDay = <DateTime, List<ExtraHours>>{};
        for (final hours in widget.store.extraHours) {
          final day =
              DateTime(hours.date.year, hours.date.month, hours.date.day);
          extraByDay.putIfAbsent(day, () => []).add(hours);
        }
        final monthSessions = widget.store.sessions
            .where((session) =>
                session.date.year == _visibleMonth.year &&
                session.date.month == _visibleMonth.month)
            .toList();
        // Total du mois affiché : séances (préparation et rangement compris)
        // et heures hors séances.
        final monthMinutes = monthSessions.fold(
                0, (sum, session) => sum + session.totalMinutes) +
            extraHoursMinutes(widget.store.extraHours.where((hours) =>
                hours.date.year == _visibleMonth.year &&
                hours.date.month == _visibleMonth.month));

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _MonthHeader(
              label: widget.store.monthYearLabel(_visibleMonth),
              sessionCount: monthSessions.length,
              totalMinutes: monthMinutes,
              onPrevious: () => _changeMonth(-1, byDay),
              onNext: () => _changeMonth(1, byDay),
              onToday: _goToToday,
            ),
            const SizedBox(height: 8),
            _WeekdayHeader(weekdays: widget.store.weekdays),
            const SizedBox(height: 4),
            _MonthGrid(
              month: _visibleMonth,
              selectedDay: _selectedDay,
              sessionsByDay: byDay,
              extraHoursByDay: extraByDay,
              onSelectDay: _selectDay,
            ),
            const SizedBox(height: 20),
            _DayDetails(
              dayLabel: widget.store.fullDateLabel(_selectedDay),
              sessions: byDay[_selectedDay] ?? const [],
              extraHours: extraByDay[_selectedDay] ?? const [],
              store: widget.store,
              onOpen: _openDetails,
              onAdd: () => _addOnDay(_selectedDay),
            ),
          ],
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.sessionCount,
    required this.totalMinutes,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final int sessionCount;
  final int totalMinutes;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.onPrimary;
    const onHeader = Colors.white;

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  color: accent,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevious,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: onHeader),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        // Un mois sans séance peut avoir des heures hors
                        // séances : on affiche alors quand même le total.
                        sessionCount == 0 && totalMinutes == 0
                            ? 'Aucune séance ce mois'
                            : '$sessionCount séance${sessionCount > 1 ? 's' : ''}'
                                ' · ${formatDuration(totalMinutes)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onHeader),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  color: accent,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: accent),
                onPressed: onToday,
                icon: const Icon(Icons.today, size: 18),
                label: const Text("Aujourd'hui"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.weekdays});

  final List<CalendarWeekday> weekdays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final weekday in weekdays)
          Expanded(
            child: Center(
              child: Text(
                weekday.abreviation,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
      ],
    );
  }
}

// Grille du mois : 7 colonnes (lundi → dimanche), une case par jour.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.sessionsByDay,
    required this.extraHoursByDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<DateTime, List<TrainingSession>> sessionsByDay;
  final Map<DateTime, List<ExtraHours>> extraHoursByDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    // Astuce : le « jour 0 » du mois suivant est le dernier jour de ce mois,
    // ce qui donne le nombre de jours (28, 29, 30 ou 31).
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // La semaine commence le lundi : weekday == 1 pour lundi.
    final leadingEmptyCells = firstDay.weekday - DateTime.monday;
    // Nombre de cases arrondi à des semaines complètes. `~/` = division entière.
    final totalCells = ((leadingEmptyCells + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      // La grille ne défile pas elle-même : c'est toute la page qui défile.
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        // Les cases avant le 1er (et après le dernier jour) restent vides.
        final dayNumber = index - leadingEmptyCells + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = DateTime(month.year, month.month, dayNumber);
        final sessions = sessionsByDay[day] ?? const <TrainingSession>[];

        return _DayCell(
          key: Key('calendar-day-${month.year}-${month.month}-$dayNumber'),
          day: day,
          // Les heures hors séances ajoutent aussi un point sous le jour.
          sessionCount: sessions.length + (extraHoursByDay[day]?.length ?? 0),
          selected: _isSameDay(day, selectedDay),
          isToday: _isSameDay(day, DateTime.now()),
          onTap: () => onSelectDay(day),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.sessionCount,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final int sessionCount;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dotCount = sessionCount > 3 ? 3 : sessionCount;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? colors.primary
            : sessionCount > 0
                ? colors.primaryContainer
                : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isToday && !selected
              ? BorderSide(color: colors.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: selected ? colors.onPrimary : null,
                  fontWeight:
                      sessionCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < dotCount; i++)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: selected ? colors.onPrimary : colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sous la grille : les séances du jour sélectionné, leur total et le bouton
// « Ajouter » qui crée une séance à cette date.
class _DayDetails extends StatelessWidget {
  const _DayDetails({
    required this.dayLabel,
    required this.sessions,
    required this.extraHours,
    required this.store,
    required this.onOpen,
    required this.onAdd,
  });

  final String dayLabel;
  final List<TrainingSession> sessions;
  final List<ExtraHours> extraHours;
  final SessionStore store;
  final ValueChanged<TrainingSession> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes =
        sessions.fold(0, (sum, session) => sum + session.totalMinutes) +
            extraHoursMinutes(extraHours);
    final isEmpty = sessions.isEmpty && extraHours.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayLabel,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEmpty
                        ? 'Aucune séance ce jour-là'
                        : [
                            if (sessions.isNotEmpty)
                              '${sessions.length} séance'
                                  '${sessions.length > 1 ? 's' : ''}',
                            if (extraHours.isNotEmpty)
                              '${extraHours.length} hors séance'
                                  '${extraHours.length > 1 ? 's' : ''}',
                            '${formatDuration(totalMinutes)} au total',
                          ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.event_busy,
                      size: 32, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('Aucune séance enregistrée ce jour-là.'),
                ],
              ),
            ),
          )
        else ...[
          for (final session in sessions) ...[
            _SessionCard(session: session, onTap: () => onOpen(session)),
            const SizedBox(height: 8),
          ],
          for (final hours in extraHours)
            ExtraHoursTile(store: store, hours: hours, showDate: false),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final TrainingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories =
        session.categories.isEmpty ? const ['Sans catégorie'] : null;
    final labels =
        categories ?? session.categories.map((category) => category.nom);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatTimeRange(
                          session.startTime, session.durationMinutes),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: session.ballColor.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26, width: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(session.ballColor.nom, style: theme.textTheme.bodySmall),
                ],
              ),
              if (formatOnSite(session) case final onSite?) ...[
                const SizedBox(height: 2),
                Text(onSite, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in labels)
                    Chip(
                      label: Text(label),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                ],
              ),
              if (session.exercises.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.fitness_center,
                        size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${session.exercises.length} exercice'
                      '${session.exercises.length > 1 ? 's' : ''}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final exercise in session.exercises)
                      Chip(
                        label: Text(exercise.name),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  ...List.generate(
                    5,
                    (index) => Icon(
                      index < session.intensity
                          ? Icons.local_fire_department
                          : Icons.local_fire_department_outlined,
                      size: 15,
                      color: AppColors.indigo,
                    ),
                  ),
                  const Spacer(),
                  Text('Détails',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
