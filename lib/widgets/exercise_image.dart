import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Aperçu de l'image d'un exercice : l'image est affichée EN ENTIER
/// (réduite si besoin, jamais rognée), sur un fond sombre. Un appui l'ouvre
/// en plein écran, avec zoom.
///
/// Les schémas d'exercices sont très hauts : un aperçu rogné n'en montrait
/// qu'un morceau.
class ExerciseImagePreview extends StatelessWidget {
  const ExerciseImagePreview({
    super.key,
    required this.image,
    required this.title,
    this.height = 320,
    this.borderRadius = 12,
  });

  final Uint8List image;

  /// Titre de l'écran plein écran (nom de l'exercice).
  final String title;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Material(
        color: const Color(0xFF1B2440),
        child: InkWell(
          onTap: () => openFullImage(context, image: image, title: title),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.memory(
                    image,
                    // contain : toute l'image est visible.
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.zoom_in,
                        size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre l'image en plein écran par-dessus l'écran actuel.
void openFullImage(
  BuildContext context, {
  required Uint8List image,
  required String title,
}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => FullImageScreen(image: image, title: title),
  ));
}

/// Image en plein écran, sur fond noir.
class FullImageScreen extends StatelessWidget {
  const FullImageScreen({super.key, required this.image, required this.title});

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
      body: SizedBox.expand(
        // InteractiveViewer : zoom avec deux doigts et déplacement de l'image.
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.memory(image, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
