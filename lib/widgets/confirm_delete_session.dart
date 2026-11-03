import 'package:flutter/material.dart';

import '../models/models.dart';

/// Demande confirmation avant de supprimer une séance.
Future<bool> confirmDeleteSession(
    BuildContext context, TrainingSession session) async {
  final localizations = MaterialLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Supprimer la séance ?'),
      content: Text(
        'La séance du ${localizations.formatMediumDate(session.date)} '
        'sera supprimée définitivement.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
