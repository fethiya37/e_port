// lib/screens/route_assignments_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/route_assignments.dart';
import '../utils/ethiopian_calendar.dart'; // ecFromIsoShort / ecFormatFullFromGc

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

    setState(() { loading = true; error = null; result = null; });
    final res = await fetchVisibleCoverage(plateNumber: plate);
    setState(() {
      loading = false;
      if (res.success) {
        result = res.data!;
      } else {
        error = res.error ?? 'Failed to load assignments';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    final headerTitleStyle = GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  Text('Route Assignments', style: headerTitleStyle),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) => _doSearch(),
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Enter plate number (e.g. AA-123456)',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search, color: Colors.black54),
                          onPressed: loading || _searchCtrl.text.trim().isEmpty ? null : _doSearch,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (error != null)
                    _InfoCard(
                      color: Colors.red.shade700,
                      border: Colors.red.shade200,
                      bg: Colors.red.withOpacity(0.06),
                      child: Text(error!, style: const TextStyle(color: Colors.black87)),
                    ),

                  if (result != null) ...[
                    // Coverage window or inactive message
                    if (!result!.coverageActive)
                      _InfoCard(
                        color: Colors.orange.shade800,
                        border: Colors.orange.shade200,
                        bg: Colors.orange.withOpacity(0.08),
                        child: const Text('Coverage is inactive. No current/future route assignments are visible.'),
                      )
                    else
                      _CoverageWindowCard(result: result!),

                    if (result!.coverageActive && result!.assignments.isEmpty)
                      _InfoCard(
                        color: Colors.blueGrey.shade700,
                        border: Colors.blueGrey.shade200,
                        bg: Colors.blueGrey.withOpacity(0.08),
                        child: const Text('No assignments scheduled in the current → future coverage window.'),
                      ),

                    // List of assignments
                    for (final a in result!.assignments) _AssignmentTile(a: a),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== UI bits =====

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child, required this.color, required this.border, required this.bg});
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
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: DefaultTextStyle(style: TextStyle(color: color), child: child),
    );
  }
}

class _CoverageWindowCard extends StatelessWidget {
  const _CoverageWindowCard({required this.result});
  final VisibleCoverage result;

  @override
  Widget build(BuildContext context) {
    final fromEc = result.windowFrom == null ? '—' : ecFormatFullFromGc(result.windowFrom!);
    final toEc   = result.windowTo   == null ? '—' : ecFormatFullFromGc(result.windowTo!);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Visible Window (EC)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$fromEc → $toEc', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
          const SizedBox(height: 4),
          Text(result.isWeekly == true ? 'Weekly periods' : 'Monthly periods',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
    final endEc   = ecFormatFullFromGc(a.endDate);
    final statusColor = a.status == 'Approved' ? Colors.green : Colors.orange;
    final routeTitle = a.route.group == null
        ? '${a.route.departure} → ${a.route.arrival}'
        : '${a.route.group}: ${a.route.departure} → ${a.route.arrival}';

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
