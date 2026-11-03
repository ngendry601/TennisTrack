import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_track/utils/date_ranges.dart';

void main() {
  test('la semaine va du lundi au dimanche', () {
    final saturday = DateTime(2026, 10, 24);

    expect(startOfWeek(saturday), DateTime(2026, 10, 19));
    expect(endOfWeekExclusive(saturday), DateTime(2026, 10, 26));

    expect(isInSameWeek(DateTime(2026, 10, 18), saturday), isFalse);
    expect(isInSameWeek(DateTime(2026, 10, 19), saturday), isTrue);
    expect(isInSameWeek(DateTime(2026, 10, 25), saturday), isTrue);
    expect(isInSameWeek(DateTime(2026, 10, 26), saturday), isFalse);
  });

  test('la semaine peut traverser deux mois ou deux années', () {
    expect(startOfWeek(DateTime(2026, 1, 1)), DateTime(2025, 12, 29));
    expect(isInSameWeek(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), isTrue);
  });

  test('compare les mois civils', () {
    expect(
        isInSameMonth(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), isTrue);
    expect(
        isInSameMonth(DateTime(2026, 9, 30), DateTime(2026, 10, 1)), isFalse);
    expect(
        isInSameMonth(DateTime(2025, 10, 1), DateTime(2026, 10, 1)), isFalse);
  });
}
