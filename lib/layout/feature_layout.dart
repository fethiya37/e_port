import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeatureLayout extends StatelessWidget {
  const FeatureLayout({
    super.key,
    required this.title,
    this.icon,
    this.headerChild,
    required this.body,
    this.headerHeightFactor = 0.23,
  });

  final String title;
  final IconData? icon;
  final Widget? headerChild;
  final Widget body;
  final double headerHeightFactor;

  static const _gradA = Color(0xFF0ea5e9); // Sky 500
  static const _gradB = Color(0xFF0284c7); // Sky 600
  static const _gradC = Color(0xFF0c4a6e); // Sky 900

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final safeTop = mq.padding.top;
    final headerH = (h * headerHeightFactor).clamp(160.0, 260.0);

    return Scaffold(
      body: Container(
        height: h,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: [_gradA, _gradB, _gradC],
          ),
        ),
        child: Column(
          children: [
            // ===== Gradient Header =====
            Container(
              height: headerH,
              padding: EdgeInsets.fromLTRB(20, safeTop + 12, 20, 20),
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null)
                        Icon(icon, color: Colors.white, size: 22),
                      if (icon != null) const SizedBox(width: 8),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (headerChild != null) ...[
                    const SizedBox(height: 20),
                    headerChild!,
                  ],
                ],
              ),
            ),

            // ===== White Rounded Sheet =====
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      24 +
                          MediaQuery.viewPaddingOf(context).bottom +
                          56, 
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
