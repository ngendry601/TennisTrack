import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/formatters.dart';

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
        final months = _groupByMonth(store.sessions);

        if (months.isEmpty) {
          return const Center(child: Text('Aucune séance enregistrée'));
        }

        final maxMinutes = months
            .map((month) => month.totalMinutes)
            .reduce((a, b) => a > b ? a : b);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
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
              _MonthCard(month: month, maxMinutes: maxMinutes),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  List<_MonthData> _groupByMonth(List<TrainingSession> sessions) {
    final grouped = <String, List<TrainingSession>>{};
    for (final session in sessions) {
      final key =
          '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(session);
    }

    final months = grouped.entries.map((entry) {
      final date = entry.value.first.date;
      return _MonthData(
          year: date.year, month: date.month, sessions: entry.value);
    }).toList();

    months.sort((a, b) => b.key.compareTo(a.key));
    return months;
  }
}

class _MonthData {
  const _MonthData({
    required this.year,
    required this.month,
    required this.sessions,
  });

  final int year;
  final int month;
  final List<TrainingSession> sessions;

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  int get totalMinutes =>
      sessions.fold(0, (sum, session) => sum + session.durationMinutes);

  /// Total de minutes par nom de catégorie pour ce mois.
  Map<String, int> get minutesByCategory {
    final totals = <String, int>{};
    for (final session in sessions) {
      if (session.categories.isEmpty) {
        totals['Sans catégorie'] =
            (totals['Sans catégorie'] ?? 0) + session.durationMinutes;
      }
      for (final category in session.categories) {
        totals[category.nom] =
            (totals[category.nom] ?? 0) + session.durationMinutes;
      }
    }
    return totals;
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.maxMinutes});

  final _MonthData month;
  final int maxMinutes;

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context)
        .formatMonthYear(DateTime(month.year, month.month));
    final categories = month.minutesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(_capitalize(label)),
        subtitle: Text(
          '${month.sessions.length} séance${month.sessions.length > 1 ? 's' : ''}'
          ' · ${formatDuration(month.totalMinutes)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxMinutes == 0 ? 0 : month.totalMinutes / maxMinutes,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label),
      ],
    );
  }
}
