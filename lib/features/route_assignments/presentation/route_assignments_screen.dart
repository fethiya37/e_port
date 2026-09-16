import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../layout/feature_layout.dart';
import '../../../widgets/language_switcher.dart';
import '../../../l10n/app_localizations.dart';
import '../data/route_assignments_api.dart';
import '../../../utils/ethiopian_calendar.dart';
import '../../auth/data/auth_service.dart';
import '../../../features/route_assignments/models/route_assignment_models.dart';
import '../../../utils/language_helper.dart';

class RouteAssignmentsScreen extends StatefulWidget {
  const RouteAssignmentsScreen({super.key, this.initialPlate});
  final String? initialPlate;

  @override
  State<RouteAssignmentsScreen> createState() => _RouteAssignmentsScreenState();
}

class _RouteAssignmentsScreenState extends State<RouteAssignmentsScreen> {
  bool _isUnauthorizedMsg(String? msg) {
    if (msg == null) return false;
    final m = msg.toLowerCase();
    return m.contains('unauthorized') ||
        m.contains('forbidden') ||
        m.contains('401') ||
        m.contains('403');
  }

  final _searchCtrl = TextEditingController();
  bool loading = false;
  String? error;
  VisibleCoverage? result;
  bool notFullFilled = false;
  bool isMaintenance = false;

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
      isMaintenance = false;
    });

    final res = await fetchVisibleCoverageByDriverId(driverId: driverId);

    if (!mounted) return;
    setState(() {
      loading = false;
      if (res.success && res.data != null) {
        if (res.data!.notFullFilled) {
          notFullFilled = true;
          if (res.data!.vehicleStatus == 'MAINTENANCE') {
            isMaintenance = true;
          }
        } else {
          result = res.data!;
          if (res.data!.plateNumber != null) {
            _searchCtrl.text = res.data!.plateNumber!;
          }
        }
      } else {
        if (!_isUnauthorizedMsg(res.error)) {
          error = res.error ?? 'መረጃ መጫን አልተሳካም።';
        }
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
      isMaintenance = false;
    });

    final res = await fetchVisibleCoverageByPlate(plateNumber: plate);

    if (!mounted) return;
    setState(() {
      loading = false;
      if (res.success && res.data != null) {
        if (res.data!.notFullFilled) {
          notFullFilled = true;
          if (res.data!.vehicleStatus == 'MAINTENANCE') {
            isMaintenance = true;
          }
        } else {
          result = res.data!;
        }
      } else {
        if (!_isUnauthorizedMsg(res.error)) {
          error = res.error ?? 'መረጃ ማግኘት አልተሳካም።';
        }
      }
    });
  }

  Widget _buildSearchHeader(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            onSubmitted: (_) => _doSearch(),
            decoration: InputDecoration(
              hintText: l10n.searchPlate,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.search, size: 22),
          ),
        ),
      ],
    );
  }

  String _getAssociationName() {
    if (currentUser?.associationName != null &&
        currentUser!.associationName!.isNotEmpty) {
      return currentUser!.associationName!;
    }
    if (currentUser?.associationId != null) {
      return 'Association #${currentUser!.associationId}';
    }
    return '—';
  }

  String _getPaidUntilText(AppLocalizations l10n, String? activeUntil) {
    if (activeUntil == null || activeUntil.isEmpty) {
      return l10n.noPayment;
    }
    final ecDate = ecFromIsoShort(activeUntil);
    return '$ecDate ${l10n.paidUntil}';
  }

  Widget _routeIllustration() {
    return Image.asset(
      'assets/illustrations/gps_navigator_amico.png',
      height: 220,
      width: 220,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.route_outlined,
          size: 130,
          color: Colors.grey.shade300,
        );
      },
    );
  }

  Widget _emptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(child: _routeIllustration()),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FeatureLayout(
      title: l10n.routeAssignments,
      icon: Icons.map_outlined,
      headerChild: _buildSearchHeader(l10n),
      headerActions: LanguageSwitcher(
        onLanguageSelected: (String languageCode) {
          LanguageHelper.changeLanguage(context, languageCode);
        },
      ),
      headerHeightFactor: 0.23,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) _infoCard(error!, Colors.red),
          if (notFullFilled && isMaintenance)
            _infoCard(l10n.maintenance, Colors.orange),
          if (notFullFilled && !isMaintenance)
            _infoCard(l10n.notFulfilled, Colors.blueGrey),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!loading && !notFullFilled && result != null) ...[
            _driverCard(result!, l10n),
            if (result!.assignments.isEmpty) _emptyState(),
            for (final a in result!.assignments) _assignmentTile(a, l10n),
            if (result!.assignments.isNotEmpty) ...[
              const SizedBox(height: 20),
              Center(child: _routeIllustration()),
              const SizedBox(height: 12),
            ],
          ],
          if (!loading && result == null && error == null && !notFullFilled)
            _emptyState(),
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

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value ?? "—",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverCard(VisibleCoverage vc, AppLocalizations l10n) {
    final isMaintenance = vc.vehicleStatus == 'MAINTENANCE';
    final associationName = _getAssociationName();
    final paidUntilText = _getPaidUntilText(l10n, vc.driverActiveUntil);
    final hasPayment =
        vc.driverActiveUntil != null && vc.driverActiveUntil!.isNotEmpty;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Text(
                      l10n.driverInfo,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (isMaintenance)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.maintenance,
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _infoRow('${l10n.driverName}:', vc.driverName ?? '—'),
              _infoRow('${l10n.plateNumber}:', vc.plateNumber ?? '—'),
              _infoRow('${l10n.association}:', associationName),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 211, 243, 245),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: Text(
              isMaintenance ? l10n.maintenance : paidUntilText,
              style: GoogleFonts.poppins(
                color: isMaintenance
                    ? Colors.orange
                    : hasPayment
                    ? const Color.fromARGB(255, 12, 130, 214)
                    : Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assignmentTile(RouteAssignmentItem a, AppLocalizations l10n) {
    final startEc = ecFormatFullFromGc(a.startDate);
    final endEc = ecFormatFullFromGc(a.endDate);
    final statusText = l10n.assigned;
    final statusColor = Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a.route.departure} → ${a.route.arrival}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$startEc → $endEc',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
