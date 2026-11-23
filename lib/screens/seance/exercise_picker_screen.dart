import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/session_store.dart';
import '../../utils/exercise_filters.dart';
import '../../widgets/exercise_widgets.dart';
import '../../widgets/session_card_frame.dart';
import 'exercise_form_screen.dart';

/// Choix d'exercices de la bibliothèque pour une séance.
///
/// Le filtre démarre sur la couleur de balle de la séance, pour ne pas
/// proposer d'exercices trop durs. Il reste modifiable.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({
    super.key,
    required this.store,
    required this.excludedIds,
    this.ballColorId,
    this.categoryIds = const {},
  });

  final SessionStore store;

  /// Exercices déjà présents dans la séance.
  final Set<int> excludedIds;
  final int? ballColorId;

  /// Thèmes de la séance, pré-cochés si un exercice est créé ici.
  final Set<int> categoryIds;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _search = TextEditingController();
  final Set<int> _selectedIds = {};
  int? _categoryId;
  late int? _ballColorId = widget.ballColorId;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _toggle(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(
          store: widget.store,
          initialCategoryIds: widget.categoryIds,
          initialBallColorId: widget.ballColorId,
        ),
      ),
    );
    if (created != null && mounted) {
      setState(() => _selectedIds.add(created.id));
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      widget.store.exercises
          .where((exercise) => _selectedIds.contains(exercise.id))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final available = widget.store.exercises
            .where((exercise) => !widget.excludedIds.contains(exercise.id))
            .toList();
        final shown = filterExercises(
          available,
          query: _search.text,
          categoryId: _categoryId,
          ballColorId: _ballColorId,
        );
        final count = _selectedIds.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ma bibliothèque'),
            actions: [
              IconButton(
                tooltip: 'Créer un exercice',
                icon: const Icon(Icons.add),
                onPressed: _create,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un exercice…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              ExerciseFilterBar(
                categories: widget.store.categories,
                ballColors: widget.store.ballColors,
                categoryId: _categoryId,
                ballColorId: _ballColorId,
                onCategoryChanged: (id) => setState(() => _categoryId = id),
                onBallColorChanged: (id) => setState(() => _ballColorId = id),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Aucun exercice disponible avec ces filtres.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _create,
                                icon: const Icon(Icons.add),
                                label: const Text('Créer un exercice'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: shown.length,
                        itemBuilder: (context, index) {
                          final exercise = shown[index];
                          final selected = _selectedIds.contains(exercise.id);
                          return SessionCardFrame(
                            child: ListTile(
                              leading: ExerciseThumbnail(exercise: exercise),
                              title: Text(
                                exercise.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: ExerciseMeta(exercise: exercise),
                              trailing: Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(exercise.id),
                              ),
                              onTap: () => _toggle(exercise.id),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: count == 0 ? null : _confirm,
                      icon: const Icon(Icons.check),
                      label: Text(
                        count == 0
                            ? 'Sélectionne un exercice'
                            : 'Ajouter $count exercice${count > 1 ? 's' : ''}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
