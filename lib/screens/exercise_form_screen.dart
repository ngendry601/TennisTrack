import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';

/// Formulaire d'un exercice : nom, points à travailler, déroulement/matériel
/// et image illustrative. L'image est renvoyée en bytes pour être stockée
/// dans SQLite avec l'exercice.
class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.exercise});

  final Exercise? exercise;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _points;
  late final TextEditingController _execution;
  Uint8List? _image;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _name = TextEditingController(text: exercise?.name ?? '');
    _points = TextEditingController(text: exercise?.pointsToWork ?? '');
    _execution = TextEditingController(text: exercise?.execution ?? '');
    _image = exercise?.image;
  }

  @override
  void dispose() {
    _name.dispose();
    _points.dispose();
    _execution.dispose();
    super.dispose();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger l’image : $error')),
      );
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donne un nom à l’exercice.')),
      );
      return;
    }

    Navigator.of(context).pop(Exercise(
      id: widget.exercise?.id ?? 0,
      name: name,
      pointsToWork: _points.text.trim(),
      execution: _execution.text.trim(),
      image: _image,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise == null
            ? 'Nouvel exercice'
            : 'Modifier l’exercice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.exercise == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom de l’exercice',
              hintText: 'Ex. : Service extérieur',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _image!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
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
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Valider l’exercice'),
          ),
        ],
      ),
    );
  }
}
