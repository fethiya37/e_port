import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'features/auth/data/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreSession();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _ui = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark,       // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Transport App',
      theme: appTheme.copyWith(
        appBarTheme: const AppBarTheme(systemOverlayStyle: _ui),
      ),
      routes: appRoutes,
      initialRoute: currentUser == null ? '/login' : '/',
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _ui,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
