import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../workspace/workspace_controller.dart';
import '../workspace/workspace_models.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/module_placeholder_screen.dart';
import '../../features/shell/presentation/sidebar_nav.dart';
import '../../features/workspace/presentation/create_workspace_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(workspaceControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState is AuthUnauthenticated) {
        return isLoggingIn ? null : '/login';
      }
      if (authState is! AuthAuthenticated) {
        return null; // still restoring the session — nothing to redirect yet
      }
      if (isLoggingIn) {
        return '/dashboard';
      }

      final isCreatingWorkspace = state.matchedLocation == '/create-workspace';
      final workspaceState = ref.read(workspaceControllerProvider);

      if (workspaceState is WorkspaceNoneExist) {
        return isCreatingWorkspace ? null : '/create-workspace';
      }
      if (workspaceState is WorkspaceSelected && isCreatingWorkspace) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/create-workspace', builder: (context, state) => const CreateWorkspaceScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authControllerProvider);
              if (authState is! AuthAuthenticated) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return AppShell(profile: authState.profile, child: child);
            },
          );
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          for (final item in sidebarNavItems.where((item) => item.route != '/dashboard'))
            GoRoute(
              path: item.route,
              builder: (context, state) => ModulePlaceholderScreen(title: item.label, icon: item.icon),
            ),
        ],
      ),
    ],
  );
});
