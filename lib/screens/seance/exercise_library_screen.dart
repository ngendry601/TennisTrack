import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/session_store.dart';
import '../../utils/exercise_filters.dart';
import '../../utils/exercise_transfer.dart';
import '../../widgets/exercise_widgets.dart';
import '../../widgets/session_card_frame.dart';
import 'exercise_form_screen.dart';

/// Onglet « Exercices » : tous les exercices, avec recherche et filtres.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    required this.store,
    this.pickImportFile = pickImportFileFromDevice,
  });

  final SessionStore store;

  /// Choix du fichier d'images à importer. Remplaçable dans les tests.
  final Future<Uint8List?> Function() pickImportFile;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

/// Ouvre l'explorateur de fichiers du téléphone (app Fichiers sur iPhone)
/// et renvoie le contenu du fichier JSON choisi, ou `null` si annulé.
Future<Uint8List?> pickImportFileFromDevice() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Fichier d’images des exercices',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  return file?.readAsBytes();
}

enum _TransferAction { copyList, importImages }

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onTransferAction(_TransferAction action) async {
    switch (action) {
      case _TransferAction.copyList:
        await _copyList();
      case _TransferAction.importImages:
        await _importImages();
    }
  }

  /// Copie la bibliothèque (sans images) pour l'envoyer à Claude.
  Future<void> _copyList() async {
    final exercises = widget.store.exercises;
    if (exercises.isEmpty) {
      _showMessage('Ta bibliothèque est vide : rien à copier.');
      return;
    }
    await Clipboard.setData(
        ClipboardData(text: exportExercisesJson(exercises)));
    if (!mounted) return;
    final count = exercises.length;
    _showMessage('Liste de $count exercice${count > 1 ? 's' : ''} copiée. '
        'Colle-la dans la conversation avec Claude.');
  }

  /// Importe le fichier d'images préparé par Claude, après confirmation.
  Future<void> _importImages() async {
    final Uint8List? bytes;
    try {
      bytes = await widget.pickImportFile();
    } catch (_) {
      _showMessage('Impossible d’ouvrir ce fichier.');
      return;
    }
    if (bytes == null || !mounted) return;

    final ImageImportPlan plan;
    try {
      final imports = parseImagesJson(utf8.decode(bytes));
      plan = planImageImport(widget.store.exercises, imports);
    } on ImageImportException catch (error) {
      _showMessage(error.message);
      return;
    } on FormatException {
      _showMessage('Ce fichier n’est pas un fichier texte JSON.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ImportDialog(plan: plan),
    );
    if (confirmed != true || plan.images.isEmpty) return;

    await widget.store.setExerciseImages(plan.images);
    if (!mounted) return;
    final count = plan.images.length;
    _showMessage('$count image${count > 1 ? 's' : ''} '
        'importée${count > 1 ? 's' : ''}.');
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
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
              child: Row(
                children: [
                  Expanded(
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
                  PopupMenuButton<_TransferAction>(
                    tooltip: 'Schémas des exercices',
                    icon: const Icon(Icons.more_vert),
                    onSelected: _onTransferAction,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _TransferAction.copyList,
                        child: ListTile(
                          leading: Icon(Icons.copy_all_outlined),
                          title: Text('Copier la liste des exercices'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _TransferAction.importImages,
                        child: ListTile(
                          leading: Icon(Icons.download_outlined),
                          title: Text('Importer les images'),
                        ),
                      ),
                    ],
                  ),
                ],
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

/// Résumé de l'import, avant de l'appliquer.
class _ImportDialog extends StatelessWidget {
  const _ImportDialog({required this.plan});

  final ImageImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final count = plan.images.length;
    final lines = <String>[
      if (count == 0)
        'Aucune image ne correspond à un exercice de ta bibliothèque.'
      else
        '$count image${count > 1 ? 's' : ''} '
            'à ajouter à tes exercices.',
      if (plan.replaced > 0)
        '${plan.replaced} exercice${plan.replaced > 1 ? 's ont' : ' a'} '
            'déjà une image : elle sera remplacée.',
      if (plan.notFound.isNotEmpty)
        'Exercice${plan.notFound.length > 1 ? 's' : ''} introuvable'
            '${plan.notFound.length > 1 ? 's' : ''} (ignoré'
            '${plan.notFound.length > 1 ? 's' : ''}) : '
            '${plan.notFound.map((name) => '« $name »').join(', ')}.',
    ];

    return AlertDialog(
      title: const Text('Importer les images ?'),
      content: Text(lines.join('\n\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(count == 0 ? 'Fermer' : 'Annuler'),
        ),
        if (count > 0)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Importer'),
          ),
      ],
    );
  }
}
