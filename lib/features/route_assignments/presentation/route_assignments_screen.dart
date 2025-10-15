import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/route_assignments_api.dart';
import '../../../utils/ethiopian_calendar.dart';
import '../../auth/data/auth_service.dart'; 
import '../../../features/route_assignments/models/route_assignment_models.dart';


class RouteAssignmentsScreen extends StatefulWidget {
  const RouteAssignmentsScreen({super.key, this.initialPlate});
  final String? initialPlate;

  @override
  State<RouteAssignmentsScreen> createState() =>
      _RouteAssignmentsScreenState();
}

class _RouteAssignmentsScreenState extends State<RouteAssignmentsScreen> {
  final _searchCtrl = TextEditingController();
  bool loading = false;
  String? error;
  VisibleCoverage? result;
  bool notFullFilled = false; // 🔑 track special case

  static const _gradA = Color(0xFF0ea5e9);
  static const _gradB = Color(0xFF0284c7);
  static const _gradC = Color(0xFF0c4a6e);

  @override
  void initState() {
    super.initState();

    if (currentUser?.userType == 'Driver' && currentUser?.driverId != null) {
      _loadForDriver(currentUser!.driverId!);
    } else if (widget.initialPlate != null &&
        widget.initialPlate!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialPlate!;
      _doSearch();
    }
  }

  Future<void> _loadForDriver(int driverId) async {
    setState(() {
      loading = true;
      error = null;
      result = null;
      notFullFilled = false;
    });

    final res = await fetchVisibleCoverageByDriverId(driverId: driverId);
    setState(() {
      loading = false;
      if (res.success && res.data != null) {
        if (res.data!.notFullFilled) {
          notFullFilled = true;
        } else {
          result = res.data!;
          if (res.data!.plateNumber != null) {
            _searchCtrl.text = res.data!.plateNumber!;
          }
        }
      } else {
        error = res.error ?? 'መረጃ መጫን አልተሳካም።';
      }
    });
  }

  Future<void> _doSearch() async {
    final plate = _searchCtrl.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    setState(() {
      loading = true;
      error = null;
      result = null;
      notFullFilled = false;
    });

    final res = await fetchVisibleCoverageByPlate(plateNumber: plate);
    setState(() {
      loading = false;
      if (res.success && res.data != null) {
        if (res.data!.notFullFilled) {
          notFullFilled = true;
        } else {
          result = res.data!;
        }
      } else {
        error = res.error ?? 'መረጃ ማግኘት አልተሳካም።';
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
            _buildHeader(safeTop, headerH),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (error != null) _infoCard(error!, Colors.red),

                        if (notFullFilled) _infoCard('አልተሟላም።', Colors.blueGrey),

                        if (!notFullFilled && result != null) ...[
                          _driverCard(result!),
                          _coverageCard(result!),
                          if (result!.assignments.isEmpty)
                            _infoCard(
                              'ምደባ የሎትም።',
                              Colors.blueGrey,
                            ),
                          for (final a in result!.assignments)
                            _assignmentTile(a),
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

  Widget _buildHeader(double safeTop, double headerH) {
    return Container(
      height: headerH,
      padding: EdgeInsets.fromLTRB(20, safeTop + 12, 20, 20),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'ስምሪት',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  onSubmitted: (_) => _doSearch(),
                  decoration: InputDecoration(
                    hintText: 'የታርጋ ቁጥር ያስገቡ (AA-123456)',
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.white70, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.white70, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.white, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.search, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String msg, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg,
          style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w500),
        ),
      );

  Widget _driverCard(VisibleCoverage vc) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('የአሽከርካሪ መረጃ',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('አሽከርካሪ፦ ${vc.driverName ?? "—"}'),
            Text('ታርጋ ቁጥር ፦ ${vc.plateNumber ?? "—"}'),
            Text('ማህበር፦ ${vc.associationName ?? "—"}'),
          ],
        ),
      );

  Widget _coverageCard(VisibleCoverage vc) {
    final ecActiveUntil = (vc.driverActiveUntil == null)
        ? '—'
        : ecFromIsoShort(vc.driverActiveUntil!);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          const Text('እስከዚህ ቀን ድረስ ከፍለዋል: ',
              style: TextStyle(color: Colors.black54)),
          Text(ecActiveUntil,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _gradB,
              )),
        ],
      ),
    );
  }

  Widget _assignmentTile(RouteAssignmentItem a) {
    final startEc = ecFormatFullFromGc(a.startDate);
    final endEc = ecFormatFullFromGc(a.endDate);
    final isApproved = a.status == 'Approved';
    final statusText = isApproved ? 'ተረጋግጧል' : 'በሂደት ላይ';
    final statusColor = isApproved ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${a.route.departure} → ${a.route.arrival}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$startEc → $endEc'),
        ],
      ),
    );
  }
}
