import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_screen.dart';
import '../../features/epd_management/presentation/views/epd_dashboard_screen.dart';
import '../../features/carwash_management/presentation/views/carwash_dashboard_screen.dart';
import '../../features/dashboard/presentation/views/dashboard_screen.dart';

/// Listenable que se usa para refrescar GoRouter cuando cambia el auth state.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(Ref ref) {
    ref.listen<AuthState>(authViewModelProvider, (_, __) {
      notifyListeners();
    });
  }
}

final _authNotifierProvider = Provider<AuthNotifier>((ref) {
  return AuthNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // Leemos el estado actual SIN watch (dentro del redirect)
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authViewModelProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'carwash',
            builder: (context, state) => const CarwashDashboardScreen(),
          ),
          GoRoute(
            path: 'eficent',
            builder: (context, state) => const EpdDashboardScreen(),
          ),
        ],
      ),
    ],
  );
});
