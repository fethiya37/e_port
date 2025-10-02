import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.child,
    required this.color,
    required this.border,
    required this.bg,
  });

  final Widget child;
  final Color color;
  final Color border;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: DefaultTextStyle(style: TextStyle(color: color), child: child),
    );
  }
}
