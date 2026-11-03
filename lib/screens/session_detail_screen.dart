import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/formatters.dart';
import 'session_form_screen.dart';

/// Détails en lecture seule d'une séance.
///
/// Un appui sur une séance (accueil, liste ou calendrier) ouvre cet écran.
/// Le bouton « Modifier » lance ensuite le formulaire d'édition.
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({
    super.key,
    required this.store,
    required this.session,
  });

  final SessionStore store;
  final TrainingSession session;

  Future<void> _edit(BuildContext context, TrainingSession current) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionFormScreen(store: store, session: current),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // La séance peut avoir été modifiée : on relit la version à jour
        // dans le store plutôt que d'utiliser l'objet passé en paramètre.
        final current = store.sessions.firstWhere(
          (item) => item.id == session.id,
          orElse: () => session,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Détails de la séance'),
            actions: [
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(context, current),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SessionSummary(session: current),
              const SizedBox(height: 20),
              Text(
                'Catégories',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _CategoryChips(categories: current.categories),
              const SizedBox(height: 20),
              Text(
                'Exercices (${current.exercises.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (current.exercises.isEmpty)
                Text(
                  'Aucun exercice pour cette séance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final exercise in current.exercises) ...[
                  _ExerciseDetails(exercise: exercise),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _edit(context, current),
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(context).formatFullDate(session.date);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _capitalize(date),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.schedule,
              label: session.startTime == null
                  ? 'Durée : ${formatDuration(session.durationMinutes)}'
                  : formatTimeRange(session.startTime, session.durationMinutes),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Durée : ${formatDuration(session.durationMinutes)}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Intensité : ${session.intensity} / 5'),
                const SizedBox(width: 8),
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < session.intensity
                        ? Icons.local_fire_department
                        : Icons.local_fire_department_outlined,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: session.ballColor.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Couleur de balle : ${session.ballColor.nom}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories});

  final List<TrainingCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text('Sans catégorie');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          Chip(
            avatar: Icon(category.icon, size: 18),
            label: Text(category.nom),
          ),
      ],
    );
  }
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Exercise exercise;

  void _showImage(BuildContext context) {
    final image = exercise.image;
    if (image == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullImageScreen(image: image, title: exercise.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (exercise.image != null)
            InkWell(
              onTap: () => _showImage(context),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.memory(
                    exercise.image!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.zoom_in,
                        size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fitness_center,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (exercise.pointsToWork.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _ExerciseLabel(label: 'Points à travailler'),
                  const SizedBox(height: 2),
                  Text(exercise.pointsToWork),
                ],
                if (exercise.execution.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _ExerciseLabel(label: 'Déroulement et matériel'),
                  const SizedBox(height: 2),
                  Text(exercise.execution),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseLabel extends StatelessWidget {
  const _ExerciseLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _FullImageScreen extends StatelessWidget {
  const _FullImageScreen({required this.image, required this.title});

  final Uint8List image;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.memory(image),
        ),
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
