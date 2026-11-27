import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/extra_hours.dart';
import '../utils/formatters.dart';
import '../utils/home_stats.dart';
import 'extra_hours_form_screen.dart';

/// Statistiques mensuelles : total d'heures et répartition par catégorie
/// pour chaque mois.
class MonthlyStatsScreen extends StatelessWidget {
  const MonthlyStatsScreen({super.key, required this.store});

  final SessionStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Une carte par mois, du plus récent au plus ancien.
        final months = _groupByMonth(store.sessions, store.extraHours);

        if (months.isEmpty) {
          return const Center(child: Text('Aucune séance enregistrée'));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _Total(
                        label: 'Séances',
                        value: '${store.sessions.length}',
                      ),
                    ),
                    Expanded(
                      child: _Total(
                        label: 'Total',
                        value: formatDuration(store.totalMinutes),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Heures par mois',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Une séance avec plusieurs catégories compte dans chacune.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final month in months) ...[
              _MonthCard(
                store: store,
                month: month,
                label: store.monthYearLabel(DateTime(month.year, month.month)),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  /// Regroupe séances et heures hors séances par mois (clé « 2026-11 »).
  /// Un mois avec seulement des heures hors séances a aussi sa carte.
  List<_MonthData> _groupByMonth(
    List<TrainingSession> sessions,
    List<ExtraHours> extraHours,
  ) {
    String keyOf(DateTime date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}';

    final grouped = <String, _MonthData>{};
    _MonthData monthOf(DateTime date) => grouped.putIfAbsent(
          keyOf(date),
          () => _MonthData(
              year: date.year, month: date.month, sessions: [], extraHours: []),
        );

    for (final session in sessions) {
      monthOf(session.date).sessions.add(session);
    }
    for (final hours in extraHours) {
      monthOf(hours.date).extraHours.add(hours);
    }

    final months = grouped.values.toList();

    months.sort((a, b) => b.key.compareTo(a.key));
    return months;
  }
}

class _MonthData {
  const _MonthData({
    required this.year,
    required this.month,
    required this.sessions,
    required this.extraHours,
  });

  final int year;
  final int month;
  final List<TrainingSession> sessions;

  /// Heures hors séances du mois (championnat, aide coach…).
  final List<ExtraHours> extraHours;

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  // Heures du mois : préparation + cours + rangement de chaque séance.
  int get totalMinutes =>
      sessions.fold(0, (sum, session) => sum + session.totalMinutes) +
      extraHoursMinutes(extraHours);

  /// Total de minutes par nom de catégorie pour ce mois.
  Map<String, int> get minutesByCategory {
    final totals = <String, int>{};
    for (final session in sessions) {
      if (session.categories.isEmpty) {
        totals['Sans catégorie'] =
            (totals['Sans catégorie'] ?? 0) + session.totalMinutes;
      }
      // Une séance à plusieurs catégories compte en entier dans chacune : la
      // somme des catégories peut donc dépasser le total du mois.
      for (final category in session.categories) {
        totals[category.nom] =
            (totals[category.nom] ?? 0) + session.totalMinutes;
      }
    }
    if (extraHours.isNotEmpty) {
      totals[kExtraHoursShareName] = extraHoursMinutes(extraHours);
    }
    return totals;
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.label,
    required this.store,
  });

  final _MonthData month;
  final String label;
  final SessionStore store;

  @override
  Widget build(BuildContext context) {
    final categories = month.minutesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(label),
        subtitle: Text([
          '${month.sessions.length} séance'
              '${month.sessions.length > 1 ? 's' : ''}',
          if (month.extraHours.isNotEmpty)
            '${month.extraHours.length} hors séance'
                '${month.extraHours.length > 1 ? 's' : ''}',
          formatDuration(month.totalMinutes),
        ].join(' · ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(category.key)),
                  Text(
                    formatDuration(category.value),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          // Détail des heures hors séances ; un appui permet de les
          // modifier ou de les supprimer.
          if (month.extraHours.isNotEmpty) ...[
            const Divider(),
            for (final hours in month.extraHours)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.more_time),
                title: Text(hours.label),
                subtitle: Text(MaterialLocalizations.of(context)
                    .formatMediumDate(hours.date)),
                trailing: Text(formatDuration(hours.durationMinutes)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ExtraHoursFormScreen(store: store, hours: hours),
                )),
              ),
          ],
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium
              ?.copyWith(color: theme.colorScheme.onPrimary),
        ),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
