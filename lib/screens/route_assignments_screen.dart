// lib/screens/route_assignments_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/route_assignments.dart';
import '../utils/ethiopian_calendar.dart';

class RouteAssignmentsScreen extends StatefulWidget {
  const RouteAssignmentsScreen({super.key, this.initialPlate});
  final String? initialPlate;

  @override
  State<RouteAssignmentsScreen> createState() => _RouteAssignmentsScreenState();
}

class _RouteAssignmentsScreenState extends State<RouteAssignmentsScreen> {
  final _searchCtrl = TextEditingController();
  bool loading = false;
  String? error;
  VisibleCoverage? result;

  static const _gradA = Color(0xFF0ea5e9); // Sky 500
  static const _gradB = Color(0xFF0284c7); // Sky 600
  static const _gradC = Color(0xFF0c4a6e); // Sky 900

  @override
  void initState() {
    super.initState();
    if (widget.initialPlate != null && widget.initialPlate!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialPlate!;
      _doSearch();
    }
  }

  Future<void> _doSearch() async {
    final plate = _searchCtrl.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    setState(() {
      loading = true;
      error = null;
      result = null;
    });

    final res = await fetchVisibleCoverage(plateNumber: plate);
    setState(() {
      loading = false;
      if (res.success) {
        result = res.data!;
      } else {
        error = res.error ?? 'Failed to load coverage';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final safeTop = mq.padding.top;
    final headerH = (h * 0.20).clamp(180.0, 240.0);

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
            // ===== Gradient header with title + search =====
            Container(
              height: headerH,
              padding: EdgeInsets.fromLTRB(20, safeTop + 12, 20, 20),
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with icon
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Routes',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search input + square button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          onSubmitted: (_) => _doSearch(),
                          decoration: InputDecoration(
                            hintText: 'Enter plate number (AA-123456)',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white70, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white70, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white, width: 1.2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 50,
                        width: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white70, width: 1),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: loading ? null : _doSearch,
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.search, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ===== White sheet for results =====
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (error != null)
                          _InfoCard(
                            color: Colors.red.shade700,
                            border: Colors.red.shade200,
                            bg: Colors.red.withOpacity(0.06),
                            child: Text(error!, style: const TextStyle(color: Colors.black87)),
                          ),

                        if (result != null) ...[
                          // NEW: Driver + Association card
                          _DriverAssociationCard(result: result!),

                          // Coverage window (EC)
                          _CoverageWindowCard(result: result!),

                          if (result!.coverageActive && result!.assignments.isEmpty)
                            _InfoCard(
                              color: Colors.blueGrey.shade700,
                              border: Colors.blueGrey.shade200,
                              bg: Colors.blueGrey.withOpacity(0.08),
                              child: const Text('No assignments scheduled in the current → future coverage window.'),
                            ),

                          for (final a in result!.assignments) _AssignmentTile(a: a),
                        ],
                      ],
                    ),
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

// ===== Reusable cards =====

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: DefaultTextStyle(style: TextStyle(color: color), child: child),
    );
  }
}

class _DriverAssociationCard extends StatelessWidget {
  const _DriverAssociationCard({required this.result});
  final VisibleCoverage result;

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Driver & Association', style: titleStyle),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.driverName ?? '—',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.apartment, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.associationName ?? '—',
                  style: const TextStyle(color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverageWindowCard extends StatelessWidget {
  const _CoverageWindowCard({required this.result});
  final VisibleCoverage result;

  @override
  Widget build(BuildContext context) {
    final fromEc = result.windowFrom == null ? '—' : ecFormatFullFromGc(result.windowFrom!);
    final toEc = result.windowTo == null ? '—' : ecFormatFullFromGc(result.windowTo!);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coverage Window', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '$fromEc → $toEc',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: _RouteAssignmentsScreenState._gradB,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.isWeekly == true ? 'Weekly periods' : 'Monthly periods',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.a});
  final RouteAssignmentItem a;

  @override
  Widget build(BuildContext context) {
    final startEc = ecFormatFullFromGc(a.startDate);
    final endEc = ecFormatFullFromGc(a.endDate);
    final statusColor = a.status == 'Approved' ? Colors.green : Colors.orange;

    final routeTitle = '${a.route.departure} → ${a.route.arrival}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            children: [
              Expanded(
                child: Text(routeTitle, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Text(a.status, style: TextStyle(color: statusColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$startEc → $endEc', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.directions_car, size: 14, color: Colors.black54),
              const SizedBox(width: 4),
              Text(a.vehiclePlate ?? '—', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              const Spacer(),
              Icon(a.isWeekly ? Icons.date_range : Icons.calendar_month, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text(a.isWeekly ? 'Weekly' : 'Monthly', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
