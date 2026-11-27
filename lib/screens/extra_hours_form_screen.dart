import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/extra_hours.dart';
import '../utils/formatters.dart';

/// FORMULAIRE « AUTRES HEURES » : heures passées hors des séances
/// (championnat, aide coach…), avec une date, une durée et un commentaire.
/// Sert à la création (hours == null) et à la modification, avec un bouton
/// de suppression.
class ExtraHoursFormScreen extends StatefulWidget {
  const ExtraHoursFormScreen({
    super.key,
    required this.store,
    this.hours,
    this.initialDate,
  });

  final SessionStore store;

  /// Entrée à modifier, ou null pour en créer une.
  final ExtraHours? hours;

  /// Date proposée pour une nouvelle entrée (jour choisi dans le
  /// calendrier). Par défaut : aujourd'hui.
  final DateTime? initialDate;

  @override
  State<ExtraHoursFormScreen> createState() => _ExtraHoursFormScreenState();
}

class _ExtraHoursFormScreenState extends State<ExtraHoursFormScreen> {
  late DateTime _date;
  late double _duration;
  late final TextEditingController _comment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final hours = widget.hours;
    _date = hours?.date ?? widget.initialDate ?? DateTime.now();
    // Le curseur va de 15 min à 12h, par pas de 15 min.
    _duration = (hours?.durationMinutes ?? 120)
        .clamp(15, kMaxExtraHoursMinutes)
        .toDouble();
    _comment = TextEditingController(text: hours?.comment ?? '');
    // Redessine pour mettre en avant la suggestion choisie.
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.store.saveExtraHours(ExtraHours(
      id: widget.hours?.id ?? 0,
      date: _date,
      durationMinutes: _duration.round(),
      comment: _comment.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final hours = widget.hours;
    if (hours == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ces heures ?'),
        content: Text('« ${hours.label} » '
            '(${formatDuration(hours.durationMinutes)}) sera supprimé.'),
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
    if (confirmed != true || !mounted) return;
    await widget.store.removeExtraHours(hours.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = extraHoursCommentSuggestions(widget.store.extraHours);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hours == null
            ? 'Ajouter des heures'
            : 'Modifier les heures'),
        actions: [
          if (widget.hours != null)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Heures en dehors des séances (championnat, aide coach…). '
            'Elles comptent dans tes heures.',
            style: theme.textTheme.bodySmall,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title:
                Text(MaterialLocalizations.of(context).formatFullDate(_date)),
            onTap: _pickDate,
          ),
          Text('Durée : ${formatDuration(_duration.round())}'),
          Slider(
            value: _duration,
            min: 15,
            max: kMaxExtraHoursMinutes.toDouble(),
            divisions: (kMaxExtraHoursMinutes - 15) ~/ 15,
            onChanged: (value) => setState(() => _duration = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Commentaire',
              hintText: 'Ex. : Championnat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // Suggestions : un appui remplit le commentaire.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final suggestion in suggestions)
                ChoiceChip(
                  label: Text(suggestion),
                  showCheckmark: false,
                  selected: _comment.text.trim().toLowerCase() ==
                      suggestion.toLowerCase(),
                  onSelected: (_) => _comment.text = suggestion,
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
