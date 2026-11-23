import 'package:flutter/material.dart';

/// Carte sombre autour d'une ligne de séance dans les listes.
class SessionCardFrame extends StatelessWidget {
  const SessionCardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(clipBehavior: Clip.antiAlias, child: child),
    );
  }
}
