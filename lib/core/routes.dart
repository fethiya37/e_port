import 'package:flutter/material.dart';
import '../features/auth/presentation/login_screen.dart';
import '../layout/main_layout.dart';

/// Global navigator key for global navigation and logout redirection
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// App routes map
final Map<String, WidgetBuilder> appRoutes = {
  '/login': (_) => LoginScreen(
        onLoginSuccess: () =>
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false),
      ),
  '/': (_) => const MainLayout(onLogout: _noop),
};

void _noop() {}
