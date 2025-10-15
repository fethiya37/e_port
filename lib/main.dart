import 'package:flutter/material.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'features/auth/data/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreSession();

  debugPrint("👉 Using API Base URL: ${AppConfig.baseUrl}");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // from routes.dart
      debugShowCheckedModeBanner: false,
      title: 'Transport App',
      theme: appTheme, // from theme.dart
      routes: appRoutes, // from routes.dart
      initialRoute: currentUser == null ? '/login' : '/', // from auth_service.dart
    );
  }
}
