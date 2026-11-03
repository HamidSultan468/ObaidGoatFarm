import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_models.dart';
import 'sidebar_nav.dart';
import 'top_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.profile});

  final Widget child;
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          SidebarNav(currentRoute: currentRoute, onSelect: (route) => context.go(route)),
          Expanded(
            child: Column(
              children: [
                TopBar(profile: profile, onLogout: () => ref.read(authControllerProvider.notifier).logout()),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
