import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/farm/farm_format.dart';
import 'package:app/core/farm/farm_repository.dart';

void main() {
  group('formatDate', () {
    test('formats an API (UTC midnight) date without shifting the day', () {
      expect(formatDate(DateTime.parse('2026-11-01T00:00:00.000Z')), '01 Nov 2026');
    });

    test('formats a local date by its calendar day', () {
      expect(formatDate(DateTime(2026, 2, 28, 23, 30)), '28 Feb 2026');
    });
  });

  group('ageLabel', () {
    final now = DateTime(2026, 11, 4);

    test('null without a birth date or for a future date', () {
      expect(ageLabel(null, now), isNull);
      expect(ageLabel(DateTime(2027, 1, 1), now), isNull);
    });

    test('days under one month', () {
      expect(ageLabel(DateTime(2026, 10, 23), now), '12d');
    });

    test('months under one year, counting only completed months', () {
      expect(ageLabel(DateTime(2026, 6, 4), now), '5m');
      expect(ageLabel(DateTime(2026, 6, 5), now), '4m');
    });

    test('years and months', () {
      expect(ageLabel(DateTime(2024, 8, 1), now), '2y 3m');
      expect(ageLabel(DateTime(2024, 11, 4), now), '2y');
    });
  });

  test('humanizeEnum', () {
    expect(humanizeEnum('UNDER_TREATMENT'), 'Under treatment');
    expect(humanizeEnum('MALE'), 'Male');
    expect(humanizeEnum(''), '');
  });

  test('trimDecimal never parses to double', () {
    expect(trimDecimal('33.500'), '33.5');
    expect(trimDecimal('40.000'), '40');
    expect(trimDecimal('12'), '12');
    expect(trimDecimal('0.125'), '0.125');
  });

  group('dueLabel', () {
    final now = DateTime(2026, 11, 4, 18);

    test('future, today, tomorrow', () {
      expect(dueLabel(DateTime.parse('2026-11-04T00:00:00Z'), now), 'today');
      expect(dueLabel(DateTime.parse('2026-11-05T00:00:00Z'), now), 'tomorrow');
      expect(dueLabel(DateTime.parse('2026-11-20T00:00:00Z'), now), 'in 16 days');
    });

    test('overdue', () {
      expect(dueLabel(DateTime.parse('2026-11-03T00:00:00Z'), now), '1 day overdue');
      expect(dueLabel(DateTime.parse('2026-10-25T00:00:00Z'), now), '10 days overdue');
    });
  });

  test('apiDate sends a plain calendar date', () {
    expect(apiDate(DateTime.utc(2026, 3, 7)), '2026-03-07');
  });
}
