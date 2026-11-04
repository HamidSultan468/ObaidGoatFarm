import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/backup/backup.dart';

void main() {
  test('BackupItem.fromJson reads counts into a readable summary', () {
    final b = BackupItem.fromJson({
      'id': 'b1',
      'trigger': 'MANUAL',
      'status': 'COMPLETED',
      'sizeBytes': 20480,
      'counts': {'animals': 12, 'journalEntries': 48, 'landParcels': 3, 'attachments': 2, 'accounts': 7},
      'error': null,
      'startedAt': '2026-11-04T06:00:00.000Z',
      'completedAt': '2026-11-04T06:00:02.000Z',
    });
    expect(b.isCompleted, isTrue);
    expect(b.summary, '12 animals · 48 transactions · 3 land · 2 documents');
  });

  test('a failed backup has no summary and keeps its error', () {
    final b = BackupItem.fromJson({
      'id': 'b2',
      'trigger': 'SCHEDULED',
      'status': 'FAILED',
      'sizeBytes': null,
      'counts': null,
      'error': 'Attachment x failed its integrity check',
      'startedAt': '2026-11-04T02:00:00.000Z',
      'completedAt': null,
    });
    expect(b.isCompleted, isFalse);
    expect(b.summary, '');
    expect(b.error, contains('integrity'));
  });

  test('BackupStatus.fromJson handles a workspace with no backups yet', () {
    final s = BackupStatus.fromJson({
      'autoBackupEnabled': true,
      'retention': 7,
      'lastBackup': null,
      'lastSuccessfulBackup': null,
      'backupCount': 0,
      'backupBytes': 0,
      'documentBytes': 1024,
      'provider': {'id': 'LOCAL', 'connected': true},
    });
    expect(s.lastSuccessfulBackup, isNull);
    expect(s.retention, 7);
  });
}
