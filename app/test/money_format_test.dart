import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/accounting/money_format.dart';

void main() {
  group('formatMoney', () {
    test('formats a numeric(18,4) string to 2 decimals with grouping', () {
      expect(formatMoney('5000.0000'), '5,000.00');
    });

    test('keeps the sign on negatives', () {
      expect(formatMoney('-1200.0000'), '-1,200.00');
    });

    test('rounds half away from zero', () {
      expect(formatMoney('0.0050'), '0.01');
      expect(formatMoney('-0.0050'), '-0.01');
      expect(formatMoney('1234567.8950'), '1,234,567.90');
    });

    test('handles zero and short inputs', () {
      expect(formatMoney('0'), '0.00');
      expect(formatMoney('0.0000'), '0.00');
      expect(formatMoney('-0.0001'), '0.00');
      expect(formatMoney('7'), '7.00');
      expect(formatMoney('12.5'), '12.50');
    });

    test('naturalBalance shows credit-normal accounts positive', () {
      expect(formatMoney(naturalBalance('-5000.0000', 'INCOME')), '5,000.00');
      expect(formatMoney(naturalBalance('-250.0000', 'LIABILITY')), '250.00');
      expect(formatMoney(naturalBalance('100.0000', 'EQUITY')), '-100.00');
      expect(formatMoney(naturalBalance('0.0000', 'INCOME')), '0.00');
    });

    test('naturalBalance leaves debit-normal accounts unchanged', () {
      expect(naturalBalance('5000.0000', 'ASSET'), '5000.0000');
      expect(naturalBalance('1200.0000', 'EXPENSE'), '1200.0000');
    });

    test('stays exact beyond double precision', () {
      // 99,999,999,999,999.9999 has more significant digits than a double can hold.
      expect(formatMoney('99999999999999.9949'), '99,999,999,999,999.99');
    });
  });
}
