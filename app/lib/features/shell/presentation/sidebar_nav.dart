import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SidebarNavItem {
  const SidebarNavItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}

const sidebarNavItems = <SidebarNavItem>[
  SidebarNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
  SidebarNavItem(icon: Icons.groups_rounded, label: 'Household Accounts', route: '/household-accounts'),
  SidebarNavItem(icon: Icons.folder_copy_rounded, label: 'My Records', route: '/records'),
  SidebarNavItem(icon: Icons.pets_rounded, label: 'Goat Farm', route: '/goat-farm'),
  SidebarNavItem(icon: Icons.landscape_rounded, label: 'Land Records', route: '/land'),
  SidebarNavItem(icon: Icons.inventory_2_rounded, label: 'Inventory', route: '/inventory'),
  SidebarNavItem(icon: Icons.handshake_rounded, label: 'Customers & Suppliers', route: '/contacts'),
  SidebarNavItem(icon: Icons.account_balance_rounded, label: 'Bank & Accounts', route: '/accounts'),
  SidebarNavItem(icon: Icons.insights_rounded, label: 'Reports & Analytics', route: '/reports'),
  SidebarNavItem(icon: Icons.smart_toy_rounded, label: 'AI Assistant', route: '/ai-assistant'),
  SidebarNavItem(icon: Icons.notifications_rounded, label: 'Notifications', route: '/notifications'),
  SidebarNavItem(icon: Icons.settings_rounded, label: 'Settings', route: '/settings'),
];

class SidebarNav extends StatelessWidget {
  const SidebarNav({super.key, required this.currentRoute, required this.onSelect});

  final String currentRoute;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppColors.sidebarNavy,
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
              children: sidebarNavItems.map((item) => _NavTile(item: item, isActive: item.route == currentRoute, onTap: () => onSelect(item.route))).toList(),
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
        color: isActive ? AppColors.sidebarNavyActive : Colors.transparent,
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
                    item.label,
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
