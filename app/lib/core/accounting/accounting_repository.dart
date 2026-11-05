import 'package:dio/dio.dart';
import '../api/api_client.dart';
import 'accounting_models.dart';

/// Header the backend's IdempotencyInterceptor keys retries on (see
/// DECISIONS.md D037): resending the same key + body replays the first
/// result instead of posting twice — what makes the offline outbox safe.
Options _idempotent(String? key) => Options(headers: key == null ? null : {'Idempotency-Key': key});

class AccountingRepository {
  AccountingRepository(this._apiClient);

  final ApiClient _apiClient;

  // --- Accounts ---

  Future<List<Account>> listAccounts(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/accounts');
    return (response.data as List).map((json) => Account.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<String> getAccountBalance(String workspaceId, String accountId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/accounts/$accountId/balance');
    return (response.data as Map<String, dynamic>)['balance'] as String;
  }

  Future<List<AccountStatementRow>> getAccountStatement(String workspaceId, String accountId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/accounts/$accountId/statement');
    final rows = (response.data as Map<String, dynamic>)['rows'] as List;
    return rows.map((row) => AccountStatementRow.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<Account> createAccount(String workspaceId, {required String code, required String name, required String type}) async {
    final response = await _apiClient.raw.post('/workspaces/$workspaceId/accounts', data: {'code': code, 'name': name, 'type': type});
    return Account.fromJson(response.data as Map<String, dynamic>);
  }

  /// Bank reconciliation: flags (or clears) one journal line as matched
  /// against a real bank statement. Never changes the amount.
  Future<void> setLineReconciled(String workspaceId, String accountId, String lineId, bool reconciled) async {
    await _apiClient.raw.patch('/workspaces/$workspaceId/accounts/$accountId/lines/$lineId/reconcile', data: {'reconciled': reconciled});
  }

  // --- Contacts ---

  Future<List<Contact>> listContacts(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/contacts');
    return (response.data as List).map((json) => Contact.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Contact> createContact(String workspaceId, {required String type, required String name, String? email, String? phone}) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/contacts',
      data: {'type': type, 'name': name, 'email': ?email, 'phone': ?phone},
    );
    return Contact.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Transactions ---

  Future<List<JournalEntry>> listTransactions(String workspaceId, {int limit = 50}) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/transactions', queryParameters: {'limit': limit});
    return (response.data as List).map((json) => JournalEntry.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<JournalEntry> recordIncome(
    String workspaceId, {
    required String toAccountId,
    required String incomeAccountId,
    required String amount,
    String? memo,
    String? contactId,
    bool issueReceipt = false,
    String? animalId,
    String? landParcelId,
    String? idempotencyKey,
  }) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/transactions/income',
      data: {
        'toAccountId': toAccountId,
        'incomeAccountId': incomeAccountId,
        'amount': amount,
        if (memo != null && memo.isNotEmpty) 'memo': memo,
        'contactId': ?contactId,
        'animalId': ?animalId,
        'landParcelId': ?landParcelId,
        'issueReceipt': issueReceipt,
      },
      options: _idempotent(idempotencyKey),
    );
    return JournalEntry.fromJson(response.data as Map<String, dynamic>);
  }

  Future<JournalEntry> recordExpense(
    String workspaceId, {
    required String fromAccountId,
    required String expenseAccountId,
    required String amount,
    String? memo,
    String? contactId,
    String? animalId,
    String? landParcelId,
    String? idempotencyKey,
  }) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/transactions/expense',
      data: {
        'fromAccountId': fromAccountId,
        'expenseAccountId': expenseAccountId,
        'amount': amount,
        if (memo != null && memo.isNotEmpty) 'memo': memo,
        'contactId': ?contactId,
        'animalId': ?animalId,
        'landParcelId': ?landParcelId,
      },
      options: _idempotent(idempotencyKey),
    );
    return JournalEntry.fromJson(response.data as Map<String, dynamic>);
  }

  Future<JournalEntry> recordTransfer(
    String workspaceId, {
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    String? memo,
    String? idempotencyKey,
  }) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/transactions/transfer',
      data: {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amount': amount,
        if (memo != null && memo.isNotEmpty) 'memo': memo,
      },
      options: _idempotent(idempotencyKey),
    );
    return JournalEntry.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Reports ---

  Future<ProfitAndLossReport> getProfitAndLoss(String workspaceId, {DateTime? from, DateTime? to}) async {
    final response = await _apiClient.raw.get(
      '/workspaces/$workspaceId/reports/profit-and-loss',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    );
    return ProfitAndLossReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> getLiquidBalance(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/reports/liquid-balance');
    return (response.data as Map<String, dynamic>)['balance'] as String;
  }

  // --- Budgets ---

  Future<List<Budget>> listBudgets(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/budgets');
    return (response.data as List).map((json) => Budget.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Budget> createBudget(
    String workspaceId, {
    required String accountId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String amount,
  }) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/budgets',
      data: {
        'accountId': accountId,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'amount': amount,
      },
    );
    return Budget.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BudgetProgress> getBudgetProgress(String workspaceId, String budgetId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/budgets/$budgetId/progress');
    return BudgetProgress.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Recurring templates ---

  Future<List<RecurringTemplate>> listRecurringTemplates(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/recurring-templates');
    return (response.data as List).map((json) => RecurringTemplate.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<RecurringTemplate> createRecurringTemplate(
    String workspaceId, {
    required String name,
    required String entryType,
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    required String frequency,
    required DateTime nextRunDate,
    String? contactId,
    String? memo,
  }) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/recurring-templates',
      data: {
        'name': name,
        'entryType': entryType,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amount': amount,
        'frequency': frequency,
        'nextRunDate': nextRunDate.toIso8601String(),
        'contactId': ?contactId,
        'memo': ?memo,
      },
    );
    return RecurringTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RecurringTemplate> setRecurringTemplateActive(String workspaceId, String templateId, bool isActive) async {
    final response = await _apiClient.raw.patch('/workspaces/$workspaceId/recurring-templates/$templateId/status', data: {'isActive': isActive});
    return RecurringTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<JournalEntry> runRecurringTemplateNow(String workspaceId, String templateId) async {
    final response = await _apiClient.raw.post('/workspaces/$workspaceId/recurring-templates/$templateId/run-now');
    return JournalEntry.fromJson(response.data as Map<String, dynamic>);
  }
}
