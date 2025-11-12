import 'package:flutter/material.dart';
import '../features/auth/data/auth_service.dart';

import '../features/payments/presentation/payment_screen.dart';
import '../features/route_assignments/presentation/route_assignments_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

class MainLayout extends StatefulWidget {
  final VoidCallback onLogout;
  const MainLayout({super.key, required this.onLogout});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isDriver = currentUser?.userType == 'Driver';
    final items = <_TabItem>[
      _TabItem('ስምሪት', Icons.map_outlined, const RouteAssignmentsScreen()),
      if (isDriver)
        _TabItem('ክፍያ', Icons.payments_outlined, const PaymentScreen()),
      _TabItem('መገለጫ', Icons.person_outline,
          ProfileScreen(onLogout: widget.onLogout)),
    ];

    final clampedIndex = _index.clamp(0, items.length - 1);
    const blue = Color(0xFF0EA5E9);
    final grey = Colors.grey.shade500;

    return Scaffold(
      body: items[clampedIndex].page,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
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
                      color: selected
                          ? blue.withOpacity(0.10)
                          : Colors.transparent,
                      border: selected
                          ? const Border(
                              top: BorderSide(color: blue, width: 2),
                            )
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
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final Widget page;
  const _TabItem(this.label, this.icon, this.page);
}
