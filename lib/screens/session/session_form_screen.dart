import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/session_store.dart';
import '../../utils/exercise_durations.dart';
import '../../utils/formatters.dart';
import '../../utils/session_times.dart';
import '../seance/exercise_form_screen.dart';
import '../seance/exercise_picker_screen.dart';

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
  late double _setup;
  late double _packUp;
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
    // Nouvelle séance : même préparation et rangement que la dernière
    // séance enregistrée.
    final model = session ?? lastEnteredSession(widget.store.sessions);
    _setup = _sliderValue(model?.setupMinutes ?? 0);
    _packUp = _sliderValue(model?.packUpMinutes ?? 0);
    _intensity = (session?.intensity ?? 3).toDouble();
    _exercises = [...?session?.exercises];
  }

  /// Propose de choisir un exercice existant ou d'en créer un nouveau.
  Future<void> _addExercise() async {
    final fromLibrary = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Choisir dans ma bibliothèque'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Créer un nouvel exercice'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (fromLibrary == null || !mounted) return;

    if (fromLibrary) {
      final picked = await Navigator.of(context).push<List<Exercise>>(
        MaterialPageRoute(
          builder: (_) => ExercisePickerScreen(
            store: widget.store,
            excludedIds: {..._exercises.map((exercise) => exercise.id)},
            ballColorId: _ballColorId,
            categoryIds: _categoryIds,
          ),
        ),
      );
      if (picked != null && mounted) {
        setState(() => _exercises.addAll(picked));
      }
      return;
    }

    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(
          store: widget.store,
          initialCategoryIds: _categoryIds,
          initialBallColorId: _ballColorId,
        ),
      ),
    );
    if (exercise != null && mounted) {
      setState(() => _exercises.add(exercise));
    }
  }

  Future<void> _editExercise(int index) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(
          store: widget.store,
          exercise: _exercises[index],
        ),
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

  /// Valeur ramenée dans les bornes du curseur (0 à 60 min).
  static double _sliderValue(int minutes) =>
      minutes.clamp(0, kMaxSetupPackUpMinutes).toDouble();

  /// Heure de fin calculée avec la durée actuellement choisie.
  TimeOfDay? get _endTime {
    final start = _startTime;
    if (start == null) return null;
    final total = start.hour * 60 + start.minute + _duration.round();
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  /// « Sur place 9h00 – 10h45 · 1h45min » avec les valeurs du formulaire.
  String? get _onSite => formatOnSiteFor(
        startTime: _startTime,
        setupMinutes: _setup.round(),
        durationMinutes: _duration.round(),
        packUpMinutes: _packUp.round(),
      );

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
      setupMinutes: _setup.round(),
      packUpMinutes: _packUp.round(),
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
                  : [
                      'Durée : ${formatDuration(_duration.round())}',
                      if (_onSite case final onSite?) onSite,
                    ].join('\n'),
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
          Text('Préparation avant le cours : '
              '${formatDuration(_setup.round())}'),
          Slider(
              value: _setup,
              max: kMaxSetupPackUpMinutes.toDouble(),
              divisions: kMaxSetupPackUpMinutes ~/ 5,
              onChanged: (value) => setState(() => _setup = value)),
          Text('Rangement après le cours : '
              '${formatDuration(_packUp.round())}'),
          Slider(
              value: _packUp,
              max: kMaxSetupPackUpMinutes.toDouble(),
              divisions: kMaxSetupPackUpMinutes ~/ 5,
              onChanged: (value) => setState(() => _packUp = value)),
          if (_onSite case final onSite?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(onSite, style: Theme.of(context).textTheme.bodySmall),
            ),
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
          if (exercisesTotalLabel(_exercises, _duration.round())
              case final total?)
            _ExercisesTotal(label: total),
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
                    [
                      if (_exercises[index].durationMinutes case final minutes?)
                        formatDuration(minutes),
                      _exercises[index].pointsToWork.isEmpty
                          ? 'Points à travailler à compléter'
                          : _exercises[index].pointsToWork,
                    ].join(' · '),
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
                        tooltip: 'Retirer de la séance',
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

/// Total des durées des exercices, comparé à la durée de la séance.
class _ExercisesTotal extends StatelessWidget {
  const _ExercisesTotal({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: style?.color),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: style)),
        ],
      ),
    );
  }
}
