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

  List<TrainingSession> get sessions => List.unmodifiable(_sessions);
  List<TrainingCategory> get categories => List.unmodifiable(_categories);
  List<BallColor> get ballColors => List.unmodifiable(_ballColors);

  int get totalMinutes =>
      _sessions.fold(0, (sum, session) => sum + session.durationMinutes);

  /// Ouvre la base, charge les catégories, les couleurs et les séances.
  /// À appeler une seule fois, avant `runApp`.
  Future<void> load() async {
    final repository =
        _repository ??= TennisRepository(await openAppDatabase());

    _categories = await repository.getCategories();
    _ballColors = await repository.getBallColors();
    _sessions
      ..clear()
      ..addAll(await repository.getSessions());
    _sort();
    notifyListeners();
  }

  /// Crée la séance si `session.id == 0`, sinon la met à jour.
  /// SQLite attribue l'id lors de la création.
  Future<void> upsert(TrainingSession session) async {
    final repository = _requireRepository();

    final TrainingSession saved;
    if (session.id == 0) {
      final id = await repository.insertSession(session);
      saved = session.copyWith(id: id);
    } else {
      await repository.updateSession(session);
      saved = session;
    }

    final index = _sessions.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      _sessions[index] = saved;
    } else {
      _sessions.add(saved);
    }
    _sort();
    notifyListeners();
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
