import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_brand_colors.dart';

class SidebarNavItem {
  const SidebarNavItem({required this.icon, required this.labelOf, required this.route});
  final IconData icon;
  final String Function(AppLocalizations) labelOf;
  final String route;

  String label(BuildContext context) => labelOf(AppLocalizations.of(context)!);
}

const sidebarNavItems = <SidebarNavItem>[
  SidebarNavItem(icon: Icons.dashboard_rounded, labelOf: _navDashboard, route: '/dashboard'),
  SidebarNavItem(icon: Icons.groups_rounded, labelOf: _navHouseholdAccounts, route: '/household-accounts'),
  SidebarNavItem(icon: Icons.folder_copy_rounded, labelOf: _navMyRecords, route: '/records'),
  SidebarNavItem(icon: Icons.pets_rounded, labelOf: _navGoatFarm, route: '/goat-farm'),
  SidebarNavItem(icon: Icons.landscape_rounded, labelOf: _navLandRecords, route: '/land'),
  SidebarNavItem(icon: Icons.inventory_2_rounded, labelOf: _navInventory, route: '/inventory'),
  SidebarNavItem(icon: Icons.handshake_rounded, labelOf: _navContacts, route: '/contacts'),
  SidebarNavItem(icon: Icons.account_balance_rounded, labelOf: _navAccounts, route: '/accounts'),
  SidebarNavItem(icon: Icons.insights_rounded, labelOf: _navReports, route: '/reports'),
  SidebarNavItem(icon: Icons.smart_toy_rounded, labelOf: _navAiAssistant, route: '/ai-assistant'),
  SidebarNavItem(icon: Icons.notifications_rounded, labelOf: _navNotifications, route: '/notifications'),
  SidebarNavItem(icon: Icons.badge_rounded, labelOf: _navStaff, route: '/staff'),
  SidebarNavItem(icon: Icons.settings_rounded, labelOf: _navSettings, route: '/settings'),
];

const adminConsoleNavItem = SidebarNavItem(
  icon: Icons.admin_panel_settings_rounded,
  labelOf: _navAdminConsole,
  route: '/admin',
);

// Top-level tear-offs (not closures) so the nav item lists above can stay const.
String _navDashboard(AppLocalizations l10n) => l10n.navDashboard;
String _navHouseholdAccounts(AppLocalizations l10n) => l10n.navHouseholdAccounts;
String _navMyRecords(AppLocalizations l10n) => l10n.navMyRecords;
String _navGoatFarm(AppLocalizations l10n) => l10n.navGoatFarm;
String _navLandRecords(AppLocalizations l10n) => l10n.navLandRecords;
String _navInventory(AppLocalizations l10n) => l10n.navInventory;
String _navContacts(AppLocalizations l10n) => l10n.navContacts;
String _navAccounts(AppLocalizations l10n) => l10n.navAccounts;
String _navReports(AppLocalizations l10n) => l10n.navReports;
String _navAiAssistant(AppLocalizations l10n) => l10n.navAiAssistant;
String _navNotifications(AppLocalizations l10n) => l10n.navNotifications;
String _navStaff(AppLocalizations l10n) => l10n.navStaff;
String _navSettings(AppLocalizations l10n) => l10n.navSettings;
String _navAdminConsole(AppLocalizations l10n) => l10n.navAdminConsole;

class SidebarNav extends StatelessWidget {
  const SidebarNav({super.key, required this.currentRoute, required this.onSelect, this.showAdminConsole = false});

  final String currentRoute;
  final ValueChanged<String> onSelect;
  final bool showAdminConsole;

  @override
  Widget build(BuildContext context) {
    final items = [...sidebarNavItems, if (showAdminConsole) adminConsoleNavItem];
    final brand = AppBrandColors.of(context);

    return Container(
      width: 248,
      color: brand.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Icon(Icons.auto_graph_rounded, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tangent\nSmart Manager',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: items.map((item) => _NavTile(item: item, isActive: item.route == currentRoute, onTap: () => onSelect(item.route))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.isActive, required this.onTap});

  final SidebarNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? AppBrandColors.of(context).sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, color: isActive ? Colors.white : Colors.white70, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label(context),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
