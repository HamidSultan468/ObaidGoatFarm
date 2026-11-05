import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../workspace/workspace_controller.dart';
import '../workspace/workspace_models.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/ai_assistant/presentation/ai_assistant_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/goat_farm/presentation/animal_detail_screen.dart';
import '../../features/goat_farm/presentation/goat_farm_screen.dart';
import '../../features/land/presentation/land_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/land/presentation/parcel_detail_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/module_placeholder_screen.dart';
import '../../features/shell/presentation/sidebar_nav.dart';
import '../../features/staff/presentation/staff_screen.dart';
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

      if (state.matchedLocation == '/admin') {
        final isPlatformAdmin = authState.profile.globalRole == 'SUPER_ADMIN_OWNER' || authState.profile.globalRole == 'ADMIN';
        if (!isPlatformAdmin) {
          return '/dashboard';
        }
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
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
          GoRoute(path: '/accounts', builder: (context, state) => const AccountsScreen()),
          GoRoute(path: '/contacts', builder: (context, state) => const ContactsScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/records', builder: (context, state) => const DocumentsScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/staff', builder: (context, state) => const StaffScreen()),
          GoRoute(path: '/ai-assistant', builder: (context, state) => const AiAssistantScreen()),
          GoRoute(
            path: '/land',
            builder: (context, state) => const LandScreen(),
            routes: [
              GoRoute(
                path: 'parcels/:parcelId',
                builder: (context, state) => ParcelDetailScreen(parcelId: state.pathParameters['parcelId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/goat-farm',
            builder: (context, state) => const GoatFarmScreen(),
            routes: [
              GoRoute(
                path: 'animals/:animalId',
                builder: (context, state) => AnimalDetailScreen(animalId: state.pathParameters['animalId']!),
              ),
            ],
          ),
          for (final item in sidebarNavItems.where(
            (item) => !const ['/dashboard', '/settings', '/accounts', '/contacts', '/reports', '/goat-farm', '/land', '/records', '/notifications', '/ai-assistant', '/staff'].contains(item.route),
          ))
            GoRoute(
              path: item.route,
              builder: (context, state) => ModulePlaceholderScreen(item: item),
            ),
        ],
      ),
    ],
  );
});
