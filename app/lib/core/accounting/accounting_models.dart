class Account {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.kind,
    required this.isSystemAccount,
    required this.isActive,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    kind: json['kind'] as String,
    isSystemAccount: json['isSystemAccount'] as bool,
    isActive: json['isActive'] as bool,
  );

  final String id;
  final String code;
  final String name;
  /// ASSET | LIABILITY | EQUITY | INCOME | EXPENSE
  final String type;
  /// CASH | BANK | RECEIVABLE | PAYABLE | GENERAL
  final String kind;
  final bool isSystemAccount;
  final bool isActive;
}

class AccountStatementRow {
  const AccountStatementRow({
    required this.journalEntryId,
    required this.postedAt,
    required this.memo,
    required this.amount,
    required this.runningBalance,
  });

  factory AccountStatementRow.fromJson(Map<String, dynamic> json) => AccountStatementRow(
    journalEntryId: json['journalEntryId'] as String,
    postedAt: DateTime.parse(json['postedAt'] as String),
    memo: json['memo'] as String?,
    amount: json['amount'] as String,
    runningBalance: json['runningBalance'] as String,
  );

  final String journalEntryId;
  final DateTime postedAt;
  final String? memo;
  final String amount;
  final String runningBalance;
}

class Contact {
  const Contact({
    required this.id,
    required this.type,
    required this.name,
    this.email,
    this.phone,
    required this.isActive,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    type: json['type'] as String,
    name: json['name'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    isActive: json['isActive'] as bool,
  );

  final String id;
  /// CUSTOMER | SUPPLIER | BOTH
  final String type;
  final String name;
  final String? email;
  final String? phone;
  final bool isActive;
}

class JournalLineView {
  const JournalLineView({required this.accountName, required this.amount});

  factory JournalLineView.fromJson(Map<String, dynamic> json) => JournalLineView(
    accountName: (json['account'] as Map<String, dynamic>)['name'] as String,
    amount: json['amount'] as String,
  );

  final String accountName;
  final String amount;
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.entryType,
    required this.status,
    required this.memo,
    required this.documentNumber,
    required this.verificationCode,
    required this.postedAt,
    required this.createdAt,
    required this.lines,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String,
    entryType: json['entryType'] as String,
    status: json['status'] as String,
    memo: json['memo'] as String?,
    documentNumber: json['documentNumber'] as String?,
    verificationCode: json['verificationCode'] as String?,
    postedAt: json['postedAt'] != null ? DateTime.parse(json['postedAt'] as String) : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lines: (json['lines'] as List).map((line) => JournalLineView.fromJson(line as Map<String, dynamic>)).toList(),
  );

  final String id;
  final String entryType;
  /// POSTED | PENDING_APPROVAL | REJECTED
  final String status;
  final String? memo;
  final String? documentNumber;
  final String? verificationCode;
  final DateTime? postedAt;
  final DateTime createdAt;
  final List<JournalLineView> lines;

  /// The positive (debit) side of the entry — what a user thinks of as "the amount".
  String get displayAmount {
    for (final line in lines) {
      if (!line.amount.startsWith('-')) return line.amount;
    }
    return lines.isNotEmpty ? lines.first.amount : '0.00';
  }
}

class ProfitAndLossReport {
  const ProfitAndLossReport({required this.totalIncome, required this.totalExpense, required this.netProfit});

  factory ProfitAndLossReport.fromJson(Map<String, dynamic> json) => ProfitAndLossReport(
    totalIncome: json['totalIncome'] as String,
    totalExpense: json['totalExpense'] as String,
    netProfit: json['netProfit'] as String,
  );

  final String totalIncome;
  final String totalExpense;
  final String netProfit;
}
