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
    required this.id,
    required this.journalEntryId,
    required this.postedAt,
    required this.memo,
    required this.amount,
    required this.runningBalance,
    this.reconciledAt,
  });

  factory AccountStatementRow.fromJson(Map<String, dynamic> json) => AccountStatementRow(
    id: json['id'] as String,
    journalEntryId: json['journalEntryId'] as String,
    postedAt: DateTime.parse(json['postedAt'] as String),
    memo: json['memo'] as String?,
    amount: json['amount'] as String,
    runningBalance: json['runningBalance'] as String,
    reconciledAt: json['reconciledAt'] == null ? null : DateTime.parse(json['reconciledAt'] as String),
  );

  /// The journal *line*'s own id — what reconciliation toggles, distinct
  /// from [journalEntryId] (the whole posted entry this line belongs to).
  final String id;
  final String journalEntryId;
  final DateTime postedAt;
  final String? memo;
  final String amount;
  final DateTime? reconciledAt;
  bool get isReconciled => reconciledAt != null;
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

class Budget {
  const Budget({required this.id, required this.accountId, required this.account, required this.periodStart, required this.periodEnd, required this.amount});

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    accountId: json['accountId'] as String,
    account: Account.fromJson(json['account'] as Map<String, dynamic>),
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    amount: json['amount'] as String,
  );

  final String id;
  final String accountId;
  final Account account;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String amount;
}

class BudgetProgress {
  const BudgetProgress({required this.actual, required this.remaining, required this.percentUsed});

  factory BudgetProgress.fromJson(Map<String, dynamic> json) => BudgetProgress(
    actual: json['actual'] as String,
    remaining: json['remaining'] as String,
    percentUsed: json['percentUsed'] as String?,
  );

  final String actual;
  final String remaining;
  /// Null when the budgeted amount is zero (division by zero avoided server-side).
  final String? percentUsed;
}

class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.name,
    required this.entryType,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.frequency,
    required this.nextRunDate,
    required this.isActive,
    this.contactId,
    this.memo,
  });

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) => RecurringTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    entryType: json['entryType'] as String,
    fromAccountId: json['fromAccountId'] as String,
    toAccountId: json['toAccountId'] as String,
    contactId: json['contactId'] as String?,
    amount: json['amount'] as String,
    memo: json['memo'] as String?,
    frequency: json['frequency'] as String,
    nextRunDate: DateTime.parse(json['nextRunDate'] as String),
    isActive: json['isActive'] as bool,
  );

  final String id;
  final String name;
  /// MANUAL | INCOME | EXPENSE | TRANSFER | ...
  final String entryType;
  final String fromAccountId;
  final String toAccountId;
  final String? contactId;
  final String amount;
  final String? memo;
  /// DAILY | WEEKLY | MONTHLY | YEARLY
  final String frequency;
  final DateTime nextRunDate;
  final bool isActive;
}
