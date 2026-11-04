/// Formats a server-computed decimal string (e.g. "5000.0000" from a
/// numeric(18,4) column) for display as "5,000.00". Uses BigInt minor-unit
/// arithmetic rather than parsing to `double`, so rounding stays exact even
/// for display — the same "no floating point for money" rule the backend
/// follows (DECISIONS.md D004). Rounds half away from zero to 2 places.
String formatMoney(String decimal) {
  final trimmed = decimal.trim();
  if (trimmed.isEmpty) return '0.00';

  final negative = trimmed.startsWith('-');
  final unsigned = negative || trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
  final parts = unsigned.split('.');
  final integerPart = parts[0].isEmpty ? '0' : parts[0];
  final fractionPart = (parts.length > 1 ? parts[1] : '').padRight(4, '0').substring(0, 4);

  // Value in 1/10000 units, then rounded to 1/100 units.
  final tenThousandths = BigInt.parse('$integerPart$fractionPart');
  final hundredths = (tenThousandths + BigInt.from(50)) ~/ BigInt.from(100);

  final whole = hundredths ~/ BigInt.from(100);
  final cents = (hundredths % BigInt.from(100)).toString().padLeft(2, '0');
  final grouped = _groupThousands(whole.toString());
  final isZero = hundredths == BigInt.zero;

  return '${negative && !isZero ? '-' : ''}$grouped.$cents';
}

const _creditNormalTypes = {'LIABILITY', 'EQUITY', 'INCOME'};

/// The ledger stores debits positive and credits negative, so credit-normal
/// accounts (liabilities, equity, income) carry negative balances — correct
/// bookkeeping, but "Sales Income: -5,000.00" reads as a loss to anyone who
/// isn't an accountant. This flips the sign for display only, so each
/// account shows its balance in its natural direction.
String naturalBalance(String rawBalance, String accountType) {
  if (!_creditNormalTypes.contains(accountType)) return rawBalance;
  final trimmed = rawBalance.trim();
  if (trimmed.startsWith('-')) return trimmed.substring(1);
  if (trimmed.startsWith('+')) return '-${trimmed.substring(1)}';
  return '-$trimmed';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
