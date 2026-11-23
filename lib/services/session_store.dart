import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../data/tennis_repository.dart';
import '../models/models.dart';

/// Source de vérité de l'interface : garde une copie en mémoire des
/// données (pour que les écrans restent synchrones) et écrit dans SQLite.
///
/// Les écrans écoutent ce [ChangeNotifier] et se reconstruisent après
/// chaque ajout / modification / suppression.
class SessionStore extends ChangeNotifier {
  SessionStore({TennisRepository? repository}) : _repository = repository;

  TennisRepository? _repository;

  final List<TrainingSession> _sessions = [];
  List<TrainingCategory> _categories = const [];
  List<BallColor> _ballColors = const [];
  List<CalendarWeekday> _weekdays = const [];
  List<CalendarMonth> _months = const [];
  List<Exercise> _exercises = const [];

  /// Jours du calendrier lus en base, du lundi au dimanche.
  List<CalendarWeekday> get weekdays => List.unmodifiable(_weekdays);

  /// « Octobre 2026 », à partir de la table `mois`.
  String monthYearLabel(DateTime date) =>
      '${_monthName(date.month)} ${date.year}';

  /// « Samedi 24 octobre 2026 », à partir des tables `jour_semaine` et `mois`.
  String fullDateLabel(DateTime date) {
    final weekday = _weekdays
        .where((item) => item.id == date.weekday)
        .map((item) => item.nom)
        .firstOrNull;
    final day = date.day == 1 ? '1er' : '${date.day}';
    final rest = '$day ${_monthName(date.month).toLowerCase()} ${date.year}';
    return weekday == null ? rest : '$weekday $rest';
  }

  /// « octobre », à partir de la table `mois`.
  String monthNameLower(int month) => _monthName(month).toLowerCase();

  String _monthName(int month) =>
      _months
          .where((item) => item.id == month)
          .map((item) => item.nom)
          .firstOrNull ??
      month.toString().padLeft(2, '0');

  List<TrainingSession> get sessions => List.unmodifiable(_sessions);
  List<TrainingCategory> get categories => List.unmodifiable(_categories);
  List<BallColor> get ballColors => List.unmodifiable(_ballColors);

  /// Bibliothèque d'exercices, triée par nom.
  List<Exercise> get exercises => List.unmodifiable(_exercises);

  /// Nombre de séances qui utilisent cet exercice.
  int exerciseSessionCount(int exerciseId) => _sessions
      .where((session) =>
          session.exercises.any((exercise) => exercise.id == exerciseId))
      .length;

  int get totalMinutes =>
      _sessions.fold(0, (sum, session) => sum + session.durationMinutes);

  /// Ouvre la base, charge les catégories, les couleurs et les séances.
  /// À appeler une seule fois, avant `runApp`.
  Future<void> load() async {
    final repository =
        _repository ??= TennisRepository(await openAppDatabase());

    _categories = await repository.getCategories();
    _ballColors = await repository.getBallColors();
    _weekdays = await repository.getWeekdays();
    _months = await repository.getMonths();
    await _reloadExercisesAndSessions(repository);
    notifyListeners();
  }

  /// Crée la séance si `session.id == 0`, sinon la met à jour.
  /// SQLite attribue l'id lors de la création.
  Future<void> upsert(TrainingSession session) async {
    final repository = _requireRepository();

    if (session.id == 0) {
      await repository.insertSession(session);
    } else {
      await repository.updateSession(session);
    }

    // Relecture : une séance peut avoir ajouté un exercice à la bibliothèque.
    await _reloadExercisesAndSessions(repository);
    notifyListeners();
  }

  /// Crée l'exercice si `exercise.id == 0`, sinon le met à jour dans toutes
  /// ses séances. Renvoie la version enregistrée.
  Future<Exercise> saveExercise(Exercise exercise) async {
    final repository = _requireRepository();

    final Exercise saved;
    if (exercise.id == 0) {
      saved = exercise.copyWith(id: await repository.insertExercise(exercise));
    } else {
      await repository.updateExercise(exercise);
      saved = exercise;
    }

    await _reloadExercisesAndSessions(repository);
    notifyListeners();
    return saved;
  }

  /// Supprime l'exercice de la bibliothèque et de ses séances.
  Future<void> removeExercise(int id) async {
    final repository = _requireRepository();
    await repository.deleteExercise(id);
    await _reloadExercisesAndSessions(repository);
    notifyListeners();
  }

  Future<void> _reloadExercisesAndSessions(TennisRepository repository) async {
    _exercises = await repository.getExercises();
    final sessions = await repository.getSessions();
    _sessions
      ..clear()
      ..addAll(sessions);
    _sort();
  }

  Future<void> remove(int id) async {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index >= 0) {
      _sessions.removeAt(index);
      // On prévient l'interface tout de suite : Dismissible exige que
      // l'élément ait disparu de la liste dans la même frame.
      notifyListeners();
    }
    await _requireRepository().deleteSession(id);
  }

  TennisRepository _requireRepository() {
    final repository = _repository;
    if (repository == null) {
      throw StateError(
        'SessionStore.load() doit être appelé avant toute lecture/écriture.',
      );
    }
    return repository;
  }

  void _sort() => _sessions.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
}
