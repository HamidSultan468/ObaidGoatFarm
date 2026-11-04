import 'package:flutter/material.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../notifications/presentation/widgets/notification_bell.dart';
import 'widgets/global_search_field.dart';
import 'widgets/sync_status.dart';
import 'widgets/universal_add_button.dart';
import 'widgets/workspace_switcher.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, required this.profile, required this.onLogout, this.onMenuTap});

  final UserProfile profile;
  final VoidCallback onLogout;

  /// Non-null on narrow layouts — shows a menu button that opens the drawer.
  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final isPlatformAdmin = profile.globalRole == 'SUPER_ADMIN_OWNER' || profile.globalRole == 'ADMIN';
    final isNarrow = onMenuTap != null;

    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (isNarrow) ...[
            IconButton(tooltip: AppLocalizations.of(context)!.openMenu, icon: const Icon(Icons.menu_rounded), onPressed: onMenuTap),
            const SizedBox(width: 4),
          ],
          Expanded(child: GlobalSearchField(showAdminConsole: isPlatformAdmin)),
          const SizedBox(width: 12),
          WorkspaceSwitcher(compact: isNarrow),
          const SizedBox(width: 8),
          SyncStatus(compact: isNarrow),
          const SizedBox(width: 8),
          UniversalAddButton(compact: isNarrow),
          const SizedBox(width: 8),
          const NotificationBell(),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(profile.email, style: Theme.of(context).textTheme.bodyMedium)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text(AppLocalizations.of(context)!.logOut)),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!isNarrow) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(profile.globalRole, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
                    ],
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
