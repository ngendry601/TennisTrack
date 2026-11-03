import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/formatters.dart';
import 'session_detail_screen.dart';
import 'session_form_screen.dart';

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
    _visibleMonth = DateTime(initial.year, initial.month);
    _selectedDay = DateTime(initial.year, initial.month, initial.day);
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
  Map<DateTime, List<TrainingSession>> _sessionsByDay() {
    final byDay = <DateTime, List<TrainingSession>>{};
    for (final session in widget.store.sessions) {
      final day =
          DateTime(session.date.year, session.date.month, session.date.day);
      byDay.putIfAbsent(day, () => []).add(session);
    }
    for (final sessions in byDay.values) {
      sessions.sort((a, b) {
        final startA = a.startTime;
        final startB = b.startTime;
        if (startA == null && startB == null) return b.id.compareTo(a.id);
        if (startA == null) return 1;
        if (startB == null) return -1;
        return (startA.hour * 60 + startA.minute)
            .compareTo(startB.hour * 60 + startB.minute);
      });
    }
    return byDay;
  }

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
        final monthSessions = widget.store.sessions
            .where((session) =>
                session.date.year == _visibleMonth.year &&
                session.date.month == _visibleMonth.month)
            .toList();
        final monthMinutes = monthSessions.fold(
            0, (sum, session) => sum + session.durationMinutes);

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _MonthHeader(
              month: _visibleMonth,
              sessionCount: monthSessions.length,
              totalMinutes: monthMinutes,
              onPrevious: () => _changeMonth(-1, byDay),
              onNext: () => _changeMonth(1, byDay),
              onToday: _goToToday,
            ),
            const SizedBox(height: 8),
            const _WeekdayHeader(),
            const SizedBox(height: 4),
            _MonthGrid(
              month: _visibleMonth,
              selectedDay: _selectedDay,
              sessionsByDay: byDay,
              onSelectDay: _selectDay,
            ),
            const SizedBox(height: 20),
            _DayDetails(
              day: _selectedDay,
              sessions: byDay[_selectedDay] ?? const [],
              onOpen: _openDetails,
              onAdd: () => _openForm(date: _selectedDay),
            ),
          ],
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.sessionCount,
    required this.totalMinutes,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final int sessionCount;
  final int totalMinutes;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).formatMonthYear(month);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevious,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _capitalize(label),
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        sessionCount == 0
                            ? 'Aucune séance ce mois'
                            : '$sessionCount séance${sessionCount > 1 ? 's' : ''}'
                                ' · ${formatDuration(totalMinutes)}',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
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
  const _WeekdayHeader();

  static const _labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in _labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.sessionsByDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<DateTime, List<TrainingSession>> sessionsByDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // La semaine commence le lundi : weekday == 1 pour lundi.
    final leadingEmptyCells = firstDay.weekday - DateTime.monday;
    final totalCells = ((leadingEmptyCells + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmptyCells + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = DateTime(month.year, month.month, dayNumber);
        final sessions = sessionsByDay[day] ?? const <TrainingSession>[];

        return _DayCell(
          key: Key('calendar-day-${month.year}-${month.month}-$dayNumber'),
          day: day,
          sessionCount: sessions.length,
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
        color: selected ? colors.primary : Colors.transparent,
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

class _DayDetails extends StatelessWidget {
  const _DayDetails({
    required this.day,
    required this.sessions,
    required this.onOpen,
    required this.onAdd,
  });

  final DateTime day;
  final List<TrainingSession> sessions;
  final ValueChanged<TrainingSession> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final totalMinutes =
        sessions.fold(0, (sum, session) => sum + session.durationMinutes);

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
                    _capitalize(localizations.formatFullDate(day)),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sessions.isEmpty
                        ? 'Aucune séance ce jour-là'
                        : '${sessions.length} séance'
                            '${sessions.length > 1 ? 's' : ''} · '
                            '${formatDuration(totalMinutes)} au total',
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
        if (sessions.isEmpty)
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
        else
          for (final session in sessions) ...[
            _SessionCard(session: session, onTap: () => onOpen(session)),
            const SizedBox(height: 8),
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
                      color: Colors.orange,
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

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
