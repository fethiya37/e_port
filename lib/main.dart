// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/route_assignments_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreSession(); // load token + user from secure storage
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
  bool _authed = currentUser != null;

  void _onLoginSuccess() => setState(() => _authed = true);
  void _onLogout() => setState(() => _authed = false);

  @override
  Widget build(BuildContext context) {
    if (!_authed) return LoginScreen(onLoginSuccess: _onLoginSuccess);
    return MainTabs(onLogout: _onLogout);
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final Widget page;
  _TabItem(this.label, this.icon, this.page);
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
    final isDriver = currentUser?.userType == 'Driver';

    final items = <_TabItem>[
      _TabItem('Route', Icons.map_outlined, const RouteAssignmentsScreen()),
      if (isDriver)
        _TabItem('Payment', Icons.payments_outlined, const PaymentScreen()),
      _TabItem('Profile', Icons.person_outline, ProfileScreen(onLogout: widget.onLogout)),
    ];

    // Clamp index in case the Payment tab disappears for non-drivers
    final clampedIndex = _index.clamp(0, items.length - 1);

    final blue = const Color(0xFF0EA5E9); // sky-500
    final grey = Colors.grey.shade500;

    return Scaffold(
      body: items[clampedIndex].page,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 0, right: 0, bottom: 0, top: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = i == clampedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _index = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? blue.withOpacity(0.10) : Colors.transparent,
                    border: selected
                        ? Border(top: BorderSide(color: blue, width: 2))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].icon, color: selected ? blue : grey, size: 26),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: selected ? blue : grey,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
