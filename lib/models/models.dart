import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Une catégorie de séance (Service, Coup droit, Physique…).
/// Elle vient de la table `categorie` : on peut donc en ajouter sans
/// modifier le code Dart.
///
/// Le nom `TrainingCategory` évite le conflit avec la classe `Category`
/// de Flutter (annotation de `package:flutter/foundation.dart`).
class TrainingCategory {
  const TrainingCategory({required this.id, required this.nom});

  final int id;
  final String nom;

  // fromMap fabrique l'objet à partir d'une ligne lue dans SQLite
  // ({'id': 3, 'nom': 'Revers'}). On retrouve ce même schéma dans chaque modèle.
  factory TrainingCategory.fromMap(Map<String, Object?> map) =>
      TrainingCategory(
        id: map['id'] as int,
        nom: map['nom'] as String,
      );

  /// L'icône n'est pas stockée en base : elle est associée au nom.
  /// Une catégorie inconnue reçoit l'icône tennis par défaut.
  IconData get icon => _icons[nom] ?? Icons.sports_tennis;

  static const Map<String, IconData> _icons = {
    'Service': Icons.sports_tennis,
    'Coup droit': Icons.arrow_forward,
    'Revers': Icons.arrow_back,
    'Volée / Filet': Icons.vertical_align_center,
    'Jeu de jambes': Icons.directions_run,
    'Physique': Icons.fitness_center,
    'Positionnement / Replacement': Icons.location_on,
    'Tactique': Icons.psychology,
    'Attaque': Icons.bolt,
    'Défense': Icons.shield,
  };
}

/// Couleur de balle : elle correspond au niveau du joueur.
/// Stockée dans la table `couleur_balle`, modifiable en base.
class BallColor {
  const BallColor({required this.id, required this.nom});

  final int id;
  final String nom;

  factory BallColor.fromMap(Map<String, Object?> map) => BallColor(
        id: map['id'] as int,
        nom: map['nom'] as String,
      );

  /// Couleur d'affichage associée au nom.
  Color get color => switch (nom) {
        'Rouge' => const Color(0xFFE53935),
        'Orange' => const Color(0xFFFB8C00),
        'Vert' => const Color(0xFF43A047),
        'Jaune' => const Color(0xFFFDD835),
        _ => Colors.grey,
      };
}

/// Jour de la semaine (table `jour_semaine`).
/// `id` suit `DateTime.weekday` : 1 = lundi … 7 = dimanche.
class CalendarWeekday {
  const CalendarWeekday({
    required this.id,
    required this.nom,
    required this.abreviation,
  });

  final int id;
  final String nom;
  final String abreviation;

  factory CalendarWeekday.fromMap(Map<String, Object?> map) => CalendarWeekday(
        id: map['id'] as int,
        nom: map['nom'] as String,
        abreviation: map['abreviation'] as String,
      );
}

/// Mois de l'année (table `mois`).
/// `id` suit `DateTime.month` : 1 = janvier … 12 = décembre.
class CalendarMonth {
  const CalendarMonth({
    required this.id,
    required this.nom,
    required this.abreviation,
  });

  final int id;
  final String nom;
  final String abreviation;

  factory CalendarMonth.fromMap(Map<String, Object?> map) => CalendarMonth(
        id: map['id'] as int,
        nom: map['nom'] as String,
        abreviation: map['abreviation'] as String,
      );
}

/// Un exercice de la bibliothèque, réutilisable dans plusieurs séances.
/// Le modifier met à jour toutes les séances qui l'utilisent.
///
/// `id == 0` signifie « pas encore enregistré ».
/// L'image illustrative est stockée directement dans SQLite (BLOB), pour
/// que l'exercice reste complet même si le fichier d'origine est supprimé.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.pointsToWork = '',
    this.execution = '',
    this.image,
    this.categories = const [],
    this.ballColors = const [],
    this.durationMinutes,
  });

  final int id;
  final String name;

  /// Durée de l'exercice en minutes, ou `null` si elle n'est pas renseignée.
  /// Elle est la même dans toutes les séances qui utilisent l'exercice.
  final int? durationMinutes;

  /// Points techniques / objectifs à travailler.
  final String pointsToWork;

  /// Déroulement de l'exercice, matériel compris.
  final String execution;

  /// Image illustrative (JPEG/PNG…), ou `null`.
  final Uint8List? image;

  /// Catégories travaillées (Service, Attaque…).
  final List<TrainingCategory> categories;

  /// Couleurs de balle pour lesquelles l'exercice est adapté.
  final List<BallColor> ballColors;

  factory Exercise.fromMap(Map<String, Object?> map) => Exercise(
        id: map['id'] as int,
        name: map['nom'] as String,
        pointsToWork: map['points_travailles'] as String? ?? '',
        execution: map['deroulement'] as String? ?? '',
        image: map['image'] as Uint8List?,
        durationMinutes: map['duree_minutes'] as int?,
      );

  Exercise copyWith({
    int? id,
    String? name,
    String? pointsToWork,
    String? execution,
    Uint8List? image,
    List<TrainingCategory>? categories,
    List<BallColor>? ballColors,
    int? durationMinutes,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      pointsToWork: pointsToWork ?? this.pointsToWork,
      execution: execution ?? this.execution,
      image: image ?? this.image,
      categories: categories ?? this.categories,
      ballColors: ballColors ?? this.ballColors,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

/// Une séance d'entraînement.
///
/// `id == 0` signifie « pas encore enregistrée » : c'est la base SQLite
/// qui attribue l'identifiant lors de l'insertion.
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.date,
    required this.durationMinutes,
    required this.intensity,
    required this.ballColor,
    required this.categories,
    this.startTime,
    this.exercises = const [],
    this.setupMinutes = 0,
    this.packUpMinutes = 0,
  });

  final int id;
  final DateTime date;

  /// Durée du cours lui-même.
  final int durationMinutes;

  /// Préparation et installation avant le cours (arrivée plus tôt).
  final int setupMinutes;

  /// Rangement après le cours (départ plus tard).
  final int packUpMinutes;

  /// Temps total sur place : préparation + cours + rangement.
  /// C'est cette durée qui compte dans les statistiques.
  int get totalMinutes => setupMinutes + durationMinutes + packUpMinutes;
  final int intensity; // 1 à 5
  final BallColor ballColor;
  final List<TrainingCategory> categories; // une séance a plusieurs catégories

  /// Heure de début, ou `null` pour les anciennes séances enregistrées
  /// avant l'ajout du calendrier. La durée reste toujours connue.
  final TimeOfDay? startTime;

  /// Exercices de la séance, dans l'ordre d'ajout.
  final List<Exercise> exercises;

  /// Heure de fin calculée à partir de l'heure de début et de la durée.
  TimeOfDay? get endTime {
    final start = startTime;
    if (start == null) return null;
    final total = start.hour * 60 + start.minute + durationMinutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  /// Heure d'arrivée : début du cours moins la préparation.
  TimeOfDay? get arrivalTime => _shift(startTime, -setupMinutes);

  /// Heure de départ : fin du cours plus le rangement.
  TimeOfDay? get departureTime => _shift(endTime, packUpMinutes);

  static TimeOfDay? _shift(TimeOfDay? time, int minutes) {
    if (time == null) return null;
    final total = (time.hour * 60 + time.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  // copyWith renvoie une COPIE modifiée : les modèles sont immuables (champs
  // « final »). Ex. : session.copyWith(durationMinutes: 90) garde tout le
  // reste identique. Un paramètre absent (null) garde l'ancienne valeur.
  TrainingSession copyWith({
    int? id,
    DateTime? date,
    int? durationMinutes,
    int? intensity,
    BallColor? ballColor,
    List<TrainingCategory>? categories,
    TimeOfDay? startTime,
    List<Exercise>? exercises,
    int? setupMinutes,
    int? packUpMinutes,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      ballColor: ballColor ?? this.ballColor,
      categories: categories ?? this.categories,
      startTime: startTime ?? this.startTime,
      exercises: exercises ?? this.exercises,
      setupMinutes: setupMinutes ?? this.setupMinutes,
      packUpMinutes: packUpMinutes ?? this.packUpMinutes,
    );
  }
}
