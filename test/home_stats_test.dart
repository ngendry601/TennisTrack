import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/utils/home_stats.dart';

const _ball = BallColor(id: 1, nom: 'Jaune');
const _service = TrainingCategory(id: 1, nom: 'Service');
const _jambes = TrainingCategory(id: 2, nom: 'Jeu de jambes');

TrainingSession _session(
  int id,
  DateTime date,
  int minutes,
  List<TrainingCategory> categories, {
  TimeOfDay? start,
}) =>
    TrainingSession(
      id: id,
      date: date,
      durationMinutes: minutes,
      intensity: 3,
      ballColor: _ball,
      categories: categories,
      startTime: start,
    );

void main() {
  test('calcule la part de chaque catégorie, de la plus travaillée', () {
    final shares = categoryShares([
      _session(1, DateTime(2026, 11, 2), 150, [_service]),
      _session(2, DateTime(2026, 11, 3), 60, [_jambes]),
    ]);

    expect(shares.map((share) => share.name), ['Service', 'Jeu de jambes']);
    expect(shares.map((share) => share.percent), [71, 29]);
  });

  test('une séance à plusieurs catégories compte dans chacune', () {
    final shares = categoryShares([
      _session(1, DateTime(2026, 11, 2), 60, [_service, _jambes]),
    ]);

    expect(shares.map((share) => share.percent), [100, 100]);
  });

  test('le dernier jour regroupe ses séances dans l’ordre de la journée', () {
    final older = _session(1, DateTime(2026, 11, 18), 60, [_service]);
    final evening = _session(2, DateTime(2026, 11, 20), 60, [_service],
        start: const TimeOfDay(hour: 18, minute: 0));
    final morning = _session(3, DateTime(2026, 11, 20), 60, [_service],
        start: const TimeOfDay(hour: 9, minute: 0));
    final noTime = _session(4, DateTime(2026, 11, 20), 60, [_service]);
    final future = _session(5, DateTime(2026, 11, 28), 60, [_service]);

    expect(
      latestSessionDay(
          [older, evening, future, morning, noTime], DateTime(2026, 11, 23)),
      [noTime, morning, evening],
    );
    expect(latestSessionDay([future], DateTime(2026, 11, 23)), isEmpty);
  });

  test('formate la comparaison avec le mois précédent', () {
    String compare(int current, int previous) => formatMonthComparison(
          currentMinutes: current,
          previousMinutes: previous,
          previousMonthName: 'octobre',
        );

    expect(compare(210, 60), '+2h30min par rapport à octobre');
    expect(compare(60, 120), '-1h par rapport à octobre');
    expect(compare(60, 60), "Autant d'heures qu'en octobre");
  });
}
