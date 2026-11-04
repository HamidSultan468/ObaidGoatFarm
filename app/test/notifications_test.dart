import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/notifications/notifications.dart';
import 'package:app/core/workspace/workspace_models.dart';

void main() {
  group('timeAgo', () {
    final now = DateTime(2026, 11, 4, 12);
    test('recent times', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3 h ago');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now), '2 d ago');
    });
    test('older than a week shows the date', () {
      expect(timeAgo(DateTime(2026, 10, 1), now), '01 Oct 2026');
    });
  });

  test('minutesToClock', () {
    expect(minutesToClock(0), '00:00');
    expect(minutesToClock(22 * 60 + 5), '22:05');
  });

  test('AppNotification.fromJson reads read state and the link', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'workspaceId': null,
      'category': 'FARM_HEALTH',
      'severity': 'WARNING',
      'title': 'Vaccination overdue',
      'body': 'PPR booster',
      'link': '/goat-farm/animals/a1',
      'readAt': null,
      'createdAt': '2026-11-04T06:00:00.000Z',
    });
    expect(n.isRead, isFalse);
    expect(n.link, '/goat-farm/animals/a1');
    expect(categoryLabel(n.category), 'Animal health reminders');
  });

  test('Workspace.myRole drives canManage (UI only)', () {
    Workspace ws(String? role) => Workspace.fromJson({'id': 'w', 'name': 'Farm', 'slug': 'farm', 'myRole': role});
    expect(ws('OWNER').canManage, isTrue);
    expect(ws('ADMIN').canManage, isTrue);
    expect(ws('STAFF').canManage, isFalse);
    expect(ws(null).canManage, isFalse);
  });

  test('NotificationRule round-trips to JSON for saving', () {
    final rule = NotificationRule.fromJson({'category': 'LAND_LEASE', 'isEnabled': true, 'recipientRoles': ['OWNER']});
    expect(rule.copyWith(isEnabled: false).toJson(), {'category': 'LAND_LEASE', 'isEnabled': false, 'recipientRoles': ['OWNER']});
  });
}
