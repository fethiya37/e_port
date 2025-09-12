// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/route_assignments_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreSession(); // ⬅️ load token + user from secure storage
  runApp(const MyApp());
}

final _mdButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(8),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0EA5E9), // sky-500
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: _mdButtonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: _mdButtonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: _mdButtonShape),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0.5,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: Colors.transparent,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transport App',
      theme: theme,
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _authed = currentUser != null; // now correct because we restored first

  void _onLoginSuccess() => setState(() => _authed = true);
  void _onLogout() => setState(() => _authed = false);

  @override
  Widget build(BuildContext context) {
    if (!_authed) return LoginScreen(onLoginSuccess: _onLoginSuccess);
    return MainTabs(onLogout: _onLogout);
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    final pages = [
      const RouteAssignmentsScreen(),
      const PaymentScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2)),
          ],
        ),
        child: NavigationBar(
          height: 56,
          elevation: 0,
          backgroundColor: Colors.white,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          indicatorColor: Colors.transparent,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: blue),
              selectedIcon: Icon(Icons.home, color: blue),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.credit_card_outlined, color: blue),
              selectedIcon: Icon(Icons.credit_card, color: blue),
              label: 'Payment',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: blue),
              selectedIcon: Icon(Icons.person, color: blue),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
