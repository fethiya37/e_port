import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeatureLayout extends StatelessWidget {
  const FeatureLayout({
    super.key,
    required this.title,
    this.icon,
    this.headerChild,
    required this.body,
    this.headerHeightFactor = 0.22,
    this.showHeaderLogo = false,
    this.headerActions,
  });

  final String title;
  final IconData? icon;
  final Widget? headerChild;
  final Widget body;
  final double headerHeightFactor;
  final bool showHeaderLogo;
  final Widget? headerActions;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final safeTop = mq.padding.top;
    final headerH = (h * headerHeightFactor).clamp(150.0, 240.0);
    final bottomInset = mq.viewPadding.bottom;

    return Container(
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF0EA5E9),
            Color(0xFF0284C7),
            Color(0xFF0369A1),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            height: headerH,
            padding: EdgeInsets.fromLTRB(24, safeTop + 8, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (headerActions != null) headerActions!,
                  ],
                ),
                if (headerChild != null) ...[
                  const SizedBox(height: 8),
                  Flexible(child: headerChild!),
                ],
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
                  child: SizedBox(width: double.infinity, child: body),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
