import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/date_ranges.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete_session.dart';
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

        // Plus de Scaffold/AppBar ici : c'est MainShell qui les fournit,
        // ainsi que le bouton d'ajout de séance global.
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatCard(
                      label: 'Séances ce mois',
                      value: '${monthSessions.length}'),
                  const SizedBox(width: 12),
                  _StatCard(label: 'Heures ce mois', value: hours),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Cette semaine',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${weekSessions.length} séance'
                    '${weekSessions.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
            Expanded(
              child: weekSessions.isEmpty
                  ? const Center(child: Text('Aucune séance cette semaine 🎾'))
                  : shown.isEmpty
                      ? const Center(
                          child: Text(
                              'Aucune séance ne correspond à ce filtre cette semaine'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final session = shown[i];
                            return Dismissible(
                              key: ValueKey(session.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) =>
                                  confirmDeleteSession(context, session),
                              onDismissed: (_) =>
                                  widget.store.remove(session.id),
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
                                            : Icons
                                                .local_fire_department_outlined,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _openDetails(session),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  String _categoryLabel(TrainingSession session) {
    if (session.categories.isEmpty) return 'Sans catégorie';
    return session.categories.map((category) => category.nom).join(' · ');
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
