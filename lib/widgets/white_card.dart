import 'package:flutter/material.dart';

class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
