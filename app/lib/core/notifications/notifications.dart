import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../farm/farm_format.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdAt,
    this.workspaceId,
    this.link,
    this.readAt,
  });

  final String id;
  final String? workspaceId;
  final String category;
  final String severity;
  final String title;
  final String body;
  final String? link;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    workspaceId: json['workspaceId'] as String?,
    category: json['category'] as String,
    severity: json['severity'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    link: json['link'] as String?,
    readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class CategoryPreference {
  const CategoryPreference({required this.category, required this.inApp, required this.email});
  final String category;
  final bool inApp;
  final bool email;

  CategoryPreference copyWith({bool? inApp, bool? email}) =>
      CategoryPreference(category: category, inApp: inApp ?? this.inApp, email: email ?? this.email);

  Map<String, dynamic> toJson() => {'category': category, 'inApp': inApp, 'email': email};
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.emailAvailable,
    required this.timeZone,
    required this.categories,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final bool emailAvailable;
  final String timeZone;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final List<CategoryPreference> categories;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) => NotificationPreferences(
    emailAvailable: (json['channels'] as Map<String, dynamic>)['email'] as bool,
    timeZone: json['timeZone'] as String,
    quietHoursStart: json['quietHoursStart'] as int?,
    quietHoursEnd: json['quietHoursEnd'] as int?,
    categories: (json['categories'] as List)
        .cast<Map<String, dynamic>>()
        .map((c) => CategoryPreference(category: c['category'] as String, inApp: c['inApp'] as bool, email: c['email'] as bool))
        .toList(),
  );
}

class NotificationRule {
  const NotificationRule({required this.category, required this.isEnabled, required this.recipientRoles});
  final String category;
  final bool isEnabled;
  final List<String> recipientRoles;

  NotificationRule copyWith({bool? isEnabled, List<String>? recipientRoles}) => NotificationRule(
    category: category,
    isEnabled: isEnabled ?? this.isEnabled,
    recipientRoles: recipientRoles ?? this.recipientRoles,
  );

  Map<String, dynamic> toJson() => {'category': category, 'isEnabled': isEnabled, 'recipientRoles': recipientRoles};

  factory NotificationRule.fromJson(Map<String, dynamic> json) => NotificationRule(
    category: json['category'] as String,
    isEnabled: json['isEnabled'] as bool,
    recipientRoles: (json['recipientRoles'] as List).cast<String>(),
  );
}

class DeliveryLogEntry {
  const DeliveryLogEntry({
    required this.status,
    required this.attempts,
    required this.title,
    required this.recipient,
    required this.createdAt,
    this.lastError,
    this.sentAt,
  });

  final String status;
  final int attempts;
  final String title;
  final String recipient;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? sentAt;

  factory DeliveryLogEntry.fromJson(Map<String, dynamic> json) {
    final notification = json['notification'] as Map<String, dynamic>;
    return DeliveryLogEntry(
      status: json['status'] as String,
      attempts: json['attempts'] as int,
      title: notification['title'] as String,
      recipient: (notification['user'] as Map<String, dynamic>)['email'] as String,
      lastError: json['lastError'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sentAt: json['sentAt'] == null ? null : DateTime.parse(json['sentAt'] as String),
    );
  }
}

/// Display labels for categories (English UI text; codes stay English in the API).
const notificationCategoryLabels = {
  'FARM_HEALTH': 'Animal health reminders',
  'FARM_BREEDING': 'Kidding reminders',
  'LAND_LEASE': 'Lease reminders',
  'APPROVALS': 'Transactions awaiting approval',
  'DRAFTS': 'Drafts to review',
  'BACKUP': 'Backup results',
  'ANNOUNCEMENT': 'Announcements',
};

String categoryLabel(String category) => notificationCategoryLabels[category] ?? humanizeEnum(category);

/// `just now`, `5 min ago`, `3 h ago`, `2 d ago`, then the date.
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(time);
}

/// `HH:mm` for minutes after midnight.
String minutesToClock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class NotificationsRepository {
  NotificationsRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<AppNotification>> list({required String workspaceId, bool unreadOnly = false, int limit = 50}) async {
    final response = await _apiClient.raw.get(
      '/notifications',
      queryParameters: {'workspaceId': workspaceId, 'limit': '$limit', if (unreadOnly) 'unread': 'true'},
    );
    return (response.data as List).map((json) => AppNotification.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount(String workspaceId) async {
    final response = await _apiClient.raw.get('/notifications/unread-count', queryParameters: {'workspaceId': workspaceId});
    return (response.data as Map<String, dynamic>)['count'] as int;
  }

  Future<void> markRead(String id) => _apiClient.raw.post('/notifications/$id/read');

  Future<void> markAllRead(String workspaceId) => _apiClient.raw.post('/notifications/read-all', queryParameters: {'workspaceId': workspaceId});

  Future<NotificationPreferences> getPreferences() async {
    final response = await _apiClient.raw.get('/notifications/preferences');
    return NotificationPreferences.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NotificationPreferences> savePreferences(Map<String, dynamic> body) async {
    final response = await _apiClient.raw.put('/notifications/preferences', data: body);
    return NotificationPreferences.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<NotificationRule>> getRules(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/notification-rules');
    return (response.data as List).map((json) => NotificationRule.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> saveRules(String workspaceId, List<NotificationRule> rules) async {
    await _apiClient.raw.put('/workspaces/$workspaceId/notification-rules', data: {'rules': rules.map((r) => r.toJson()).toList()});
  }

  Future<int> runRules(String workspaceId) async {
    final response = await _apiClient.raw.post('/workspaces/$workspaceId/notification-rules/run');
    return (response.data as Map<String, dynamic>)['created'] as int;
  }

  Future<int> send(String workspaceId, {required String title, required String body, required String severity, required List<String> roles}) async {
    final response = await _apiClient.raw.post(
      '/workspaces/$workspaceId/notifications/send',
      data: {'title': title, 'body': body, 'severity': severity, 'roles': roles},
    );
    return (response.data as Map<String, dynamic>)['recipients'] as int;
  }

  Future<List<DeliveryLogEntry>> deliveries(String workspaceId) async {
    final response = await _apiClient.raw.get('/workspaces/$workspaceId/notifications/deliveries');
    return (response.data as List).map((json) => DeliveryLogEntry.fromJson(json as Map<String, dynamic>)).toList();
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.read(notificationsRepositoryProvider).unreadCount(requireWorkspaceId(ref));
});

/// Latest notifications for the bell panel and the inbox (`unreadOnly` filter).
final notificationListProvider = FutureProvider.family<List<AppNotification>, bool>((ref, unreadOnly) {
  return ref.read(notificationsRepositoryProvider).list(workspaceId: requireWorkspaceId(ref), unreadOnly: unreadOnly);
});

final notificationPreferencesProvider = FutureProvider<NotificationPreferences>((ref) {
  return ref.read(notificationsRepositoryProvider).getPreferences();
});

final notificationRulesProvider = FutureProvider<List<NotificationRule>>((ref) {
  return ref.read(notificationsRepositoryProvider).getRules(requireWorkspaceId(ref));
});

final deliveryLogProvider = FutureProvider<List<DeliveryLogEntry>>((ref) {
  return ref.read(notificationsRepositoryProvider).deliveries(requireWorkspaceId(ref));
});

void refreshNotifications(WidgetRef ref) {
  ref.invalidate(unreadCountProvider);
  ref.invalidate(notificationListProvider);
}
