import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_models.dart';
import 'sidebar_nav.dart';
import 'top_bar.dart';

/// Below this width the fixed sidebar becomes a drawer (NFR-4.7 — the
/// dashboard must work on phone-width viewports, not just desktop).
const _wideLayoutBreakpoint = 900.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.profile});

  final Widget child;
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isPlatformAdmin = profile.globalRole == 'SUPER_ADMIN_OWNER' || profile.globalRole == 'ADMIN';
    final scaffoldKey = GlobalKey<ScaffoldState>();

    void onLogout() => ref.read(authControllerProvider.notifier).logout();
    void onSelect(String route) => context.go(route);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
        final sidebar = SidebarNav(currentRoute: currentRoute, onSelect: onSelect, showAdminConsole: isPlatformAdmin);

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                sidebar,
                Expanded(
                  child: Column(
                    children: [TopBar(profile: profile, onLogout: onLogout), Expanded(child: child)],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          key: scaffoldKey,
          drawer: Drawer(
            width: 248,
            child: SidebarNav(
              currentRoute: currentRoute,
              showAdminConsole: isPlatformAdmin,
              onSelect: (route) {
                scaffoldKey.currentState?.closeDrawer();
                onSelect(route);
              },
            ),
          ),
          body: Column(
            children: [
              TopBar(
                profile: profile,
                onLogout: onLogout,
                onMenuTap: () => scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
