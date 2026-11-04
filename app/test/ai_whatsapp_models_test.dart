import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/ai/ai.dart';
import 'package:app/core/whatsapp/whatsapp.dart';

void main() {
  test('RecordDraft.fromJson keeps the payload as proposed and the warnings', () {
    final d = RecordDraft.fromJson({
      'id': 'd1',
      'source': 'WHATSAPP',
      'kind': 'INCOME',
      'status': 'PENDING',
      'summary': 'Sold 2 goats for 90,000 cash',
      'payload': {'amount': '90000', 'toAccountId': 'cash', 'incomeAccountId': null},
      'warnings': ['Choose a category'],
      'sourcePhone': '+923001234567',
      'createdAt': '2026-11-04T06:00:00.000Z',
    });
    expect(d.isPending, isTrue);
    expect(d.payload['amount'], '90000');
    expect(d.payload.containsKey('incomeAccountId'), isTrue);
    expect(d.warnings, ['Choose a category']);
  });

  test('AiProviderConfig exposes only the key hint', () {
    final c = AiProviderConfig.fromJson({'id': 'p1', 'model': 'claude-opus-5-5', 'keyHint': 'AAAA', 'priority': 1, 'isEnabled': true, 'monthlyRequestLimit': null});
    expect(c.keyHint, 'AAAA');
    expect(aiModelChoices[c.model], contains('Opus 5.5'));
  });

  test('WhatsAppConfigInfo handles the not-configured response', () {
    expect(WhatsAppConfigInfo.fromJson({'configured': false}).configured, isFalse);
    final c = WhatsAppConfigInfo.fromJson({'configured': true, 'phoneNumberId': '123456', 'verifyToken': 'abc', 'isEnabled': true, 'webhookPath': '/whatsapp/webhook'});
    expect(c.webhookPath, '/whatsapp/webhook');
  });
}
