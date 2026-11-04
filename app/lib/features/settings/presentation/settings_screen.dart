import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/workspace/workspace_controller.dart';
import '../../../core/workspace/workspace_models.dart';
import 'widgets/ai_settings_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/language_section.dart';
import 'widgets/mfa_section.dart';
import 'widgets/notification_preferences_card.dart';
import 'widgets/sessions_section.dart';
import 'widgets/whatsapp_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    final workspaceState = ref.watch(workspaceControllerProvider);
    final workspace = workspaceState is WorkspaceSelected ? workspaceState.workspace : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.settingsTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          if (profile != null) _AccountCard(profile: profile),
          const SizedBox(height: 16),
          const LanguageSection(),
          const SizedBox(height: 16),
          const NotificationPreferencesCard(),
          const SizedBox(height: 16),
          if (workspace != null && workspace.canManage) ...[
            BackupSection(isOwner: workspace.myRole == 'OWNER'),
            const SizedBox(height: 16),
            const AiSettingsSection(),
            const SizedBox(height: 16),
          ],
          if (workspace != null && const ['OWNER', 'ADMIN', 'MANAGER', 'STAFF'].contains(workspace.myRole)) ...[
            WhatsAppSection(canManage: workspace.canManage),
            const SizedBox(height: 16),
          ],
          if (profile != null) MfaSection(profile: profile),
          const SizedBox(height: 16),
          const SessionsSection(),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.settingsAccountSection, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _InfoRow(label: 'Name', value: profile.fullName),
            _InfoRow(label: 'Email', value: profile.email),
            _InfoRow(label: 'Platform role', value: profile.globalRole),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
