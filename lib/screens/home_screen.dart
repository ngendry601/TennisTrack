import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_ranges.dart';
import '../utils/formatters.dart';
import '../utils/home_stats.dart';
import '../widgets/confirm_delete_session.dart';
import '../widgets/home_cards.dart';
import '../widgets/session_card_frame.dart';
import 'session/session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, this.today});

  final SessionStore store;

  /// Date de référence pour le mois et la semaine affichés.
  /// Par défaut : aujourd'hui. Utile pour les tests.
  final DateTime? today;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _filterCategoryId;

  void _openDetails(TrainingSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SessionDetailScreen(store: widget.store, session: session),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final reference = widget.today ?? DateTime.now();
        final all = widget.store.sessions;

        // Statistiques : uniquement le mois en cours.
        final monthSessions = all
            .where((session) => isInSameMonth(session.date, reference))
            .toList();
        final monthMinutes = monthSessions.fold<int>(
            0, (sum, session) => sum + session.durationMinutes);

        // Liste principale : uniquement la semaine en cours (lundi → dimanche).
        final weekSessions = all
            .where((session) => isInSameWeek(session.date, reference))
            .toList();
        final shown = _filterCategoryId == null
            ? weekSessions
            : weekSessions
                .where((session) => session.categories
                    .any((category) => category.id == _filterCategoryId))
                .toList();
        final hours = formatDuration(monthMinutes);

        // Comparaison avec le mois précédent.
        final previousMonth = DateTime(reference.year, reference.month - 1);
        final previousMinutes = all
            .where((session) => isInSameMonth(session.date, previousMonth))
            .fold<int>(0, (sum, session) => sum + session.durationMinutes);
        final comparison = monthMinutes == 0 && previousMinutes == 0
            ? null
            : formatMonthComparison(
                currentMinutes: monthMinutes,
                previousMinutes: previousMinutes,
                previousMonthName:
                    widget.store.monthNameLower(previousMonth.month),
              );
        final lastSession = latestSession(all, reference);

        // Plus de Scaffold/AppBar ici : c'est MainShell qui les fournit,
        // ainsi que le bouton d'ajout de séance global.
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _StatCard(
                        icon: Icons.sports_tennis,
                        label: 'Séances ce mois',
                        value: '${monthSessions.length}'),
                    const SizedBox(width: 12),
                    _StatCard(
                        icon: Icons.schedule,
                        label: 'Heures ce mois',
                        value: hours),
                  ],
                ),
              ),
              const _SectionTitle('Ma semaine'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: WeekStrip(
                  weekdays: widget.store.weekdays,
                  playedWeekdays: {
                    for (final session in weekSessions)
                      if (!DateTime(session.date.year, session.date.month,
                              session.date.day)
                          .isAfter(DateTime(
                              reference.year, reference.month, reference.day)))
                        session.date.weekday,
                  },
                  todayWeekday: reference.weekday,
                ),
              ),
              const _SectionTitle('Ce mois-ci'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonthBreakdownCard(
                  shares: categoryShares(monthSessions),
                  deltaMinutes: monthMinutes - previousMinutes,
                  comparison: comparison,
                ),
              ),
              if (lastSession != null) ...[
                const _SectionTitle('Dernière séance'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LastSessionCard(
                    session: lastSession,
                    dateLabel: widget.store.fullDateLabel(lastSession.date),
                    onTap: () => _openDetails(lastSession),
                  ),
                ),
              ],
              _SectionTitle(
                'Cette semaine',
                trailing: '${weekSessions.length} séance'
                    '${weekSessions.length > 1 ? 's' : ''}',
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('Toutes'),
                        selected: _filterCategoryId == null,
                        onSelected: (_) =>
                            setState(() => _filterCategoryId = null),
                      ),
                    ),
                    for (final category in widget.store.categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          avatar: Icon(category.icon, size: 18),
                          label: Text(category.nom),
                          selected: _filterCategoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _filterCategoryId = category.id),
                        ),
                      ),
                  ],
                ),
              ),
              if (weekSessions.isEmpty)
                const _EmptyMessage('Aucune séance cette semaine')
              else if (shown.isEmpty)
                const _EmptyMessage(
                    'Aucune séance ne correspond à ce filtre cette semaine')
              else
                for (final session in shown)
                  Dismissible(
                    key: ValueKey(session.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) =>
                        confirmDeleteSession(context, session),
                    onDismissed: (_) => widget.store.remove(session.id),
                    child: SessionCardFrame(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(session.categories.isEmpty
                              ? Icons.sports_tennis
                              : session.categories.first.icon),
                        ),
                        title: Text(_categoryLabel(session)),
                        subtitle: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(session.date)}'
                          ' · ${formatTimeRange(session.startTime, session.durationMinutes)}'
                          '${session.exercises.isEmpty ? '' : ' · ${session.exercises.length} exo${session.exercises.length > 1 ? 's' : ''}'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: session.ballColor.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.black26, width: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...List.generate(
                              5,
                              (n) => Icon(
                                n < session.intensity
                                    ? Icons.local_fire_department
                                    : Icons.local_fire_department_outlined,
                                size: 16,
                                color: AppColors.indigo,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openDetails(session),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  String _categoryLabel(TrainingSession session) {
    if (session.categories.isEmpty) return 'Sans catégorie';
    return session.categories.map((category) => category.nom).join(' · ');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingText = trailing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const Spacer(),
          if (trailingText != null)
            Text(trailingText, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        color: theme.colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                foregroundColor: theme.colorScheme.onPrimary,
                child: Icon(icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: theme.colorScheme.onPrimary),
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
