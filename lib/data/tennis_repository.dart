import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Toutes les lectures/écritures SQL de l'application.
/// L'interface ne parle qu'à [SessionStore], qui utilise ce repository.
class TennisRepository {
  TennisRepository(this.db);

  final Database db;

  Future<List<TrainingCategory>> getCategories() async {
    final rows = await db.query('categorie', orderBy: 'id');
    return rows.map(TrainingCategory.fromMap).toList();
  }

  Future<List<BallColor>> getBallColors() async {
    final rows = await db.query('couleur_balle', orderBy: 'id');
    return rows.map(BallColor.fromMap).toList();
  }

  Future<List<TrainingSession>> getSessions() async {
    final rows = await db.rawQuery('''
      SELECT s.id, s.date, s.duree_minutes, s.intensite, s.heure_debut,
             c.id AS couleur_id, c.nom AS couleur_nom
      FROM seance s
      JOIN couleur_balle c ON c.id = s.couleur_balle_id
      ORDER BY s.date DESC, s.id DESC
    ''');

    // Une seule requête pour tous les liens séance <-> catégorie,
    // au lieu d'une requête par séance.
    final linkRows = await db.rawQuery('''
      SELECT sc.seance_id, cat.id, cat.nom
      FROM seance_categorie sc
      JOIN categorie cat ON cat.id = sc.categorie_id
      ORDER BY cat.id
    ''');

    final categoriesBySession = <int, List<TrainingCategory>>{};
    for (final row in linkRows) {
      final sessionId = row['seance_id'] as int;
      categoriesBySession
          .putIfAbsent(sessionId, () => [])
          .add(TrainingCategory.fromMap(row));
    }

    // Les exercices (et leurs images) sont chargés en une seule requête.
    final exerciseRows = await db.query('exercice', orderBy: 'id');
    final exercisesBySession = <int, List<Exercise>>{};
    for (final row in exerciseRows) {
      final sessionId = row['seance_id'] as int;
      exercisesBySession
          .putIfAbsent(sessionId, () => [])
          .add(Exercise.fromMap(row));
    }

    return rows.map((row) {
      final id = row['id'] as int;
      return TrainingSession(
        id: id,
        date: DateTime.parse(row['date'] as String),
        durationMinutes: row['duree_minutes'] as int,
        intensity: row['intensite'] as int,
        ballColor: BallColor(
          id: row['couleur_id'] as int,
          nom: row['couleur_nom'] as String,
        ),
        categories: categoriesBySession[id] ?? const [],
        startTime: _parseTime(row['heure_debut']),
        exercises: exercisesBySession[id] ?? const [],
      );
    }).toList();
  }

  /// Insère une séance et renvoie l'id attribué par SQLite.
  Future<int> insertSession(TrainingSession session) {
    return db.transaction((txn) async {
      final id = await txn.insert('seance', _sessionValues(session));
      await _insertCategories(txn, id, session.categories);
      await _insertExercises(txn, id, session.exercises);
      return id;
    });
  }

  Future<void> updateSession(TrainingSession session) {
    return db.transaction((txn) async {
      await txn.update(
        'seance',
        _sessionValues(session),
        where: 'id = ?',
        whereArgs: [session.id],
      );
      await txn.delete(
        'seance_categorie',
        where: 'seance_id = ?',
        whereArgs: [session.id],
      );
      await _insertCategories(txn, session.id, session.categories);

      // Les exercices sont remplacés en bloc : plus simple et sans risque
      // d'identifiants obsolètes après une modification.
      await txn.delete(
        'exercice',
        where: 'seance_id = ?',
        whereArgs: [session.id],
      );
      await _insertExercises(txn, session.id, session.exercises);
    });
  }

  /// Les liens de catégories sont supprimés automatiquement par
  /// ON DELETE CASCADE (les clés étrangères sont activées à l'ouverture).
  Future<void> deleteSession(int id) =>
      db.delete('seance', where: 'id = ?', whereArgs: [id]);

  Future<void> _insertCategories(
      Transaction txn, int sessionId, List<TrainingCategory> categories) async {
    for (final category in categories) {
      await txn.insert(
        'seance_categorie',
        {'seance_id': sessionId, 'categorie_id': category.id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _insertExercises(
      Transaction txn, int sessionId, List<Exercise> exercises) async {
    for (final exercise in exercises) {
      await txn.insert('exercice', {
        'seance_id': sessionId,
        'nom': exercise.name,
        'points_travailles': exercise.pointsToWork,
        'deroulement': exercise.execution,
        'image': exercise.image,
      });
    }
  }

  Map<String, Object?> _sessionValues(TrainingSession session) => {
        'date': _dateKey(session.date),
        'duree_minutes': session.durationMinutes,
        'intensite': session.intensity,
        'couleur_balle_id': session.ballColor.id,
        'heure_debut': _timeKey(session.startTime),
      };

  /// Heure stockée au format 'HH:mm', ou `NULL` si elle n'est pas connue.
  String? _timeKey(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay? _parseTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Format 'YYYY-MM-DD', comparable et triable en SQL.
  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
