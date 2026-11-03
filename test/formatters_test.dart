import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_track/utils/formatters.dart';

void main() {
  test('formate les durées en heures et minutes', () {
    expect(formatDuration(0), '0min');
    expect(formatDuration(45), '45min');
    expect(formatDuration(60), '1h');
    expect(formatDuration(75), '1h15min');
    expect(formatDuration(90), '1h30min');
    expect(formatDuration(125), '2h05min');
    expect(formatDuration(600), '10h');
  });

  test('formate une heure et une plage horaire', () {
    expect(formatTime(const TimeOfDay(hour: 9, minute: 5)), '9h05');
    expect(
      formatTimeRange(const TimeOfDay(hour: 18, minute: 0), 75),
      '18h00 – 19h15 · 1h15min',
    );
    expect(
      formatTimeRange(const TimeOfDay(hour: 23, minute: 30), 60),
      '23h30 – 0h30 · 1h',
    );
  });

  test('affiche seulement la durée quand l’heure de début est inconnue', () {
    expect(formatTimeRange(null, 90), '1h30min');
  });
}
