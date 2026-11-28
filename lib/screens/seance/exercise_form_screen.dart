import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../services/session_store.dart';
import '../../utils/exercise_durations.dart';
import '../../utils/formatters.dart';
import '../../widgets/exercise_image.dart';
import '../../widgets/exercise_widgets.dart';

/// Formulaire d'un exercice de la bibliothèque : nom, thèmes, couleurs de
/// balle adaptées, points à travailler, déroulement et image.
///
/// La validation enregistre directement l'exercice et renvoie sa version
/// enregistrée. Une modification s'applique à toutes ses séances.
// FICHE D'EXERCICE (création ou modification). À la validation, l'exercice
// est enregistré tout de suite dans la bibliothèque, puis renvoyé à l'écran
// qui l'a ouvert (pop).
class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    super.key,
    required this.store,
    this.exercise,
    this.initialCategoryIds = const {},
    this.initialBallColorId,
  });

  final SessionStore store;
  final Exercise? exercise;

  /// Thèmes pré-cochés pour un nouvel exercice créé depuis une séance.
  final Set<int> initialCategoryIds;

  /// Couleur pré-cochée pour un nouvel exercice créé depuis une séance.
  final int? initialBallColorId;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _duration;
  late final TextEditingController _points;
  late final TextEditingController _execution;
  late final Set<int> _categoryIds;
  late final Set<int> _ballColorIds;
  Uint8List? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _name = TextEditingController(text: exercise?.name ?? '');
    _duration = TextEditingController(
        text: exercise?.durationMinutes?.toString() ?? '');
    // Redessine à chaque chiffre tapé pour mettre à jour l'aide « 1h15min ».
    _duration.addListener(() => setState(() {}));
    _points = TextEditingController(text: exercise?.pointsToWork ?? '');
    _execution = TextEditingController(text: exercise?.execution ?? '');
    _image = exercise?.image;
    _categoryIds = exercise == null
        ? {...widget.initialCategoryIds}
        : {...exercise.categories.map((category) => category.id)};
    final initialColor = widget.initialBallColorId;
    _ballColorIds = exercise == null
        ? {if (initialColor != null) initialColor}
        : {...exercise.ballColors.map((color) => color.id)};
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _points.dispose();
    _execution.dispose();
    super.dispose();
  }

  // Choix d'une image dans la galerie, réduite à 1600 px et compressée
  // (qualité 80) pour ne pas alourdir la base.
  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _image = bytes);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Impossible de charger l’image : $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      _showMessage('Donne un nom à l’exercice.');
      return;
    }
    // Durée facultative : champ vide = pas de durée. Sinon, de 1 à 240 min.
    final durationText = _duration.text.trim();
    final duration = int.tryParse(durationText);
    if (durationText.isNotEmpty &&
        (duration == null || duration <= 0 || duration > kMaxExerciseMinutes)) {
      _showMessage('La durée doit être comprise entre 1 et '
          '$kMaxExerciseMinutes minutes.');
      return;
    }
    if (_categoryIds.isEmpty) {
      _showMessage('Choisis au moins un thème.');
      return;
    }
    if (_ballColorIds.isEmpty) {
      _showMessage('Choisis au moins une couleur de balle.');
      return;
    }

    setState(() => _saving = true);
    final saved = await widget.store.saveExercise(Exercise(
      id: widget.exercise?.id ?? 0,
      name: name,
      pointsToWork: _points.text.trim(),
      execution: _execution.text.trim(),
      image: _image,
      durationMinutes: durationText.isEmpty ? null : duration,
      categories: widget.store.categories
          .where((category) => _categoryIds.contains(category.id))
          .toList(),
      ballColors: widget.store.ballColors
          .where((color) => _ballColorIds.contains(color.id))
          .toList(),
    ));
    if (mounted) Navigator.of(context).pop(saved);
  }

  /// « 1h15min » sous le champ, pour vérifier une durée en minutes.
  String? _durationHelper() {
    final minutes = int.tryParse(_duration.text.trim());
    if (minutes == null || minutes < 60) return null;
    return formatDuration(minutes);
  }

  void _toggle(Set<int> ids, int id, bool selected) {
    setState(() => selected ? ids.add(id) : ids.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.exercise;
    final usage =
        exercise == null ? 0 : widget.store.exerciseSessionCount(exercise.id);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(exercise == null ? 'Nouvel exercice' : 'Modifier l’exercice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (usage > 0) ...[
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.sync),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        usage == 1
                            ? 'Tes changements s’appliqueront à la séance '
                                'qui utilise cet exercice.'
                            : 'Tes changements s’appliqueront aux $usage '
                                'séances qui utilisent cet exercice.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _name,
            autofocus: exercise == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom de l’exercice',
              hintText: 'Ex. : Service extérieur',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            // N'autorise que les chiffres dans le champ.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Durée (facultatif)',
              hintText: 'Ex. : 15',
              suffixText: 'min',
              helperText: _durationHelper(),
              prefixIcon: const Icon(Icons.timer_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Thèmes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in widget.store.categories)
                FilterChip(
                  label: Text(category.nom),
                  showCheckmark: false,
                  selected: _categoryIds.contains(category.id),
                  onSelected: (selected) =>
                      _toggle(_categoryIds, category.id, selected),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Adapté aux balles', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in widget.store.ballColors)
                FilterChip(
                  avatar: BallDot(color: color),
                  label: Text(color.nom),
                  showCheckmark: false,
                  selected: _ballColorIds.contains(color.id),
                  onSelected: (selected) =>
                      _toggle(_ballColorIds, color.id, selected),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _points,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Points à travailler',
              hintText: 'Ex. : lancer de balle, prise de raquette…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _execution,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Déroulement et matériel',
              hintText: 'Ex. : 3 séries de 10 services avec panier de balles…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          Text('Image illustrative', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_image == null)
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Importer une image'),
            )
          else ...[
            // Image entière ; un appui l'ouvre en plein écran.
            ExerciseImagePreview(
              image: _image!,
              title: _name.text.trim().isEmpty ? 'Image' : _name.text.trim(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Changer'),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _image = null),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Valider l’exercice'),
          ),
        ],
      ),
    );
  }
}
