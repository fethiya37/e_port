import 'package:flutter/material.dart';
import '../features/auth/presentation/login_screen.dart';
import '../layout/main_layout.dart';
import '../features/auth/data/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final Map<String, WidgetBuilder> appRoutes = {
  '/login': (_) => LoginScreen(
        onLoginSuccess: () =>
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false),
      ),
  '/': (_) => MainLayout(
        onLogout: () async {
          await logout();
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (r) => false);
        },
      ),
};
