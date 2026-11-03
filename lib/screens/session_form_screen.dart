import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/formatters.dart';
import 'exercise_form_screen.dart';

class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({
    super.key,
    required this.store,
    this.session,
    this.initialDate,
  });

  final SessionStore store;
  final TrainingSession? session;

  /// Date proposée pour une nouvelle séance (jour sélectionné dans le
  /// calendrier). Ignorée si [session] est fournie.
  final DateTime? initialDate;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  late DateTime _date;
  late TimeOfDay? _startTime;
  late Set<int> _categoryIds;
  late int? _ballColorId;
  late double _duration;
  late double _intensity;
  late List<Exercise> _exercises;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _date = session?.date ?? widget.initialDate ?? DateTime.now();
    _startTime = session?.startTime;
    _categoryIds = {
      ...?session?.categories.map((category) => category.id),
    };
    if (_categoryIds.isEmpty && widget.store.categories.isNotEmpty) {
      _categoryIds.add(widget.store.categories.first.id);
    }
    _ballColorId = session?.ballColor.id ??
        (widget.store.ballColors.isEmpty
            ? null
            : widget.store.ballColors.first.id);
    _duration = (session?.durationMinutes ?? 60).toDouble();
    _intensity = (session?.intensity ?? 3).toDouble();
    _exercises = [...?session?.exercises];
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseFormScreen()),
    );
    if (exercise != null && mounted) {
      setState(() => _exercises.add(exercise));
    }
  }

  Future<void> _editExercise(int index) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(exercise: _exercises[index]),
      ),
    );
    if (exercise != null && mounted) {
      setState(() => _exercises[index] = exercise);
    }
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Heure de début de la séance',
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  /// Heure de fin calculée avec la durée actuellement choisie.
  TimeOfDay? get _endTime {
    final start = _startTime;
    if (start == null) return null;
    final total = start.hour * 60 + start.minute + _duration.round();
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  Future<void> _save() async {
    if (_categoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis au moins une catégorie.')),
      );
      return;
    }

    BallColor? ballColor;
    for (final color in widget.store.ballColors) {
      if (color.id == _ballColorId) {
        ballColor = color;
        break;
      }
    }
    if (ballColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une couleur de balle.')),
      );
      return;
    }

    final categories = widget.store.categories
        .where((category) => _categoryIds.contains(category.id))
        .toList();

    await widget.store.upsert(TrainingSession(
      id: widget.session?.id ?? 0,
      date: _date,
      durationMinutes: _duration.round(),
      intensity: _intensity.round(),
      ballColor: ballColor,
      categories: categories,
      startTime: _startTime,
      exercises: _exercises,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.session == null
              ? 'Nouvelle séance'
              : 'Modifier la séance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title:
                Text(MaterialLocalizations.of(context).formatFullDate(_date)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              _startTime == null
                  ? 'Heure de début : non renseignée'
                  : 'De ${formatTime(_startTime!)} à ${formatTime(_endTime!)}',
            ),
            subtitle: Text(
              _startTime == null
                  ? 'Appuie pour indiquer l’heure de début (facultatif)'
                  : 'Durée : ${formatDuration(_duration.round())}',
            ),
            trailing: _startTime == null
                ? null
                : IconButton(
                    tooltip: 'Effacer l’heure de début',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _startTime = null),
                  ),
            onTap: _pickStartTime,
          ),
          const SizedBox(height: 8),
          Text('Catégories', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in widget.store.categories)
                FilterChip(
                  avatar: Icon(category.icon, size: 18),
                  label: Text(category.nom),
                  selected: _categoryIds.contains(category.id),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _categoryIds.add(category.id);
                    } else {
                      _categoryIds.remove(category.id);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Couleur de balle',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final ballColor in widget.store.ballColors)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: ballColor.color,
                    radius: 8,
                    child: const SizedBox.shrink(),
                  ),
                  label: Text(ballColor.nom),
                  selected: _ballColorId == ballColor.id,
                  onSelected: (_) =>
                      setState(() => _ballColorId = ballColor.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Durée : ${formatDuration(_duration.round())}'),
          Slider(
              value: _duration,
              min: 15,
              max: 240,
              divisions: 45,
              onChanged: (value) => setState(() => _duration = value)),
          Text('Intensité : ${_intensity.round()} / 5'),
          Slider(
              value: _intensity,
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (value) => setState(() => _intensity = value)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exercices (${_exercises.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Exercice'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucun exercice. Appuie sur « Exercice » pour en ajouter un.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            for (var index = 0; index < _exercises.length; index++)
              Card(
                child: ListTile(
                  leading: _exercises[index].image == null
                      ? const CircleAvatar(
                          child: Icon(Icons.fitness_center),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _exercises[index].image!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                  title: Text(_exercises[index].name),
                  subtitle: Text(
                    _exercises[index].pointsToWork.isEmpty
                        ? 'Points à travailler à compléter'
                        : _exercises[index].pointsToWork,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_exercises[index].image != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.image_outlined, size: 20),
                        ),
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editExercise(index),
                      ),
                      IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeExercise(index),
                      ),
                    ],
                  ),
                  onTap: () => _editExercise(index),
                ),
              ),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
