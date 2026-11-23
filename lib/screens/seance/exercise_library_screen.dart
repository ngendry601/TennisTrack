import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/session_store.dart';
import '../../utils/exercise_filters.dart';
import '../../widgets/exercise_widgets.dart';
import '../../widgets/session_card_frame.dart';
import 'exercise_form_screen.dart';

/// Onglet « Exercices » : tous les exercices, avec recherche et filtres.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, required this.store});

  final SessionStore store;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  int? _categoryId;
  int? _ballColorId;

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

  void _edit(Exercise exercise) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ExerciseFormScreen(store: widget.store, exercise: exercise),
    ));
  }

  Future<void> _delete(Exercise exercise) async {
    final usage = widget.store.exerciseSessionCount(exercise.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l’exercice ?'),
        content: Text(
          usage == 0
              ? '« ${exercise.name} » sera supprimé de ta bibliothèque.'
              : '« ${exercise.name} » sera aussi retiré de '
                  '$usage séance${usage > 1 ? 's' : ''}. '
                  'Les séances sont conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.store.removeExercise(exercise.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final all = widget.store.exercises;
        final shown = filterExercises(
          all,
          query: _search.text,
          categoryId: _categoryId,
          ballColorId: _ballColorId,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un exercice…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.clear),
                          onPressed: _search.clear,
                        ),
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
                        child: Text(
                          all.isEmpty
                              ? 'Ta bibliothèque est vide. Appuie sur '
                                  '« Exercice » pour en créer un.'
                              : 'Aucun exercice ne correspond à ces filtres.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 96),
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final exercise = shown[index];
                        return SessionCardFrame(
                          child: ListTile(
                            leading: ExerciseThumbnail(exercise: exercise),
                            title: Text(
                              exercise.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: ExerciseMeta(
                              exercise: exercise,
                              usage: widget.store
                                  .exerciseSessionCount(exercise.id),
                            ),
                            trailing: IconButton(
                              tooltip: 'Supprimer l’exercice',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(exercise),
                            ),
                            onTap: () => _edit(exercise),
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
}
