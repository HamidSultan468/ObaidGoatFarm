import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/notifications/notifications.dart';

/// Per-category in-app/email choices and quiet hours for the signed-in user.
class NotificationPreferencesCard extends ConsumerStatefulWidget {
  const NotificationPreferencesCard({super.key});

  @override
  ConsumerState<NotificationPreferencesCard> createState() => _NotificationPreferencesCardState();
}

class _NotificationPreferencesCardState extends ConsumerState<NotificationPreferencesCard> {
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> body) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(notificationsRepositoryProvider).savePreferences(body);
      ref.invalidate(notificationPreferencesProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not save your preferences.'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int?> _pickTime(int? initialMinutes) async {
    final initial = initialMinutes == null ? const TimeOfDay(hour: 22, minute: 0) : TimeOfDay(hour: initialMinutes ~/ 60, minute: initialMinutes % 60);
    final picked = await showTimePicker(context: context, initialTime: initial);
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: prefs.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(apiErrorMessage(error, 'Could not load notification settings.')),
          data: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                p.emailAvailable
                    ? 'Choose where each kind of notification reaches you.'
                    : 'Email is not set up on this server yet (SMTP), so only in-app notifications are available.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  SizedBox(width: 72, child: Text('In-app', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
                  SizedBox(width: 72, child: Text('Email', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)),
                ],
              ),
              for (final c in p.categories)
                Row(
                  children: [
                    Expanded(child: Text(categoryLabel(c.category))),
                    SizedBox(
                      width: 72,
                      child: Checkbox(
                        // Announcements always reach the inbox.
                        value: c.category == 'ANNOUNCEMENT' ? true : c.inApp,
                        onChanged: _saving || c.category == 'ANNOUNCEMENT'
                            ? null
                            : (v) => _save({'categories': [c.copyWith(inApp: v ?? c.inApp).toJson()]}),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Checkbox(
                        value: c.email,
                        onChanged: _saving || !p.emailAvailable ? null : (v) => _save({'categories': [c.copyWith(email: v ?? c.email).toJson()]}),
                      ),
                    ),
                  ],
                ),
              const Divider(height: 24),
              Text('Quiet hours', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                p.quietHoursStart == null
                    ? 'Off. Emails can arrive at any time.'
                    : 'Emails wait from ${minutesToClock(p.quietHoursStart!)} to ${minutesToClock(p.quietHoursEnd!)} (${p.timeZone}). In-app notifications still appear.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final start = await _pickTime(p.quietHoursStart);
                            if (start == null || !context.mounted) return;
                            final end = await _pickTime(p.quietHoursEnd ?? 7 * 60);
                            if (end == null) return;
                            await _save({'quietHoursStart': start, 'quietHoursEnd': end});
                          },
                    icon: const Icon(Icons.bedtime_rounded),
                    label: Text(p.quietHoursStart == null ? 'Set quiet hours' : 'Change'),
                  ),
                  if (p.quietHoursStart != null)
                    TextButton(onPressed: _saving ? null : () => _save({'quietHoursStart': null, 'quietHoursEnd': null}), child: const Text('Turn off')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
