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
}
