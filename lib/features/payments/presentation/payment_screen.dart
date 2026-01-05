import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../layout/feature_layout.dart';
import '../../../utils/ethiopian_calendar.dart';
import '../../auth/data/auth_service.dart';
import '../data/payments_api.dart';
import '../models/payment_models.dart';
import 'payment_providers_screen.dart';

import '../../../widgets/common_row.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/white_card.dart';
import '../../../widgets/square_icon_button.dart';

enum PaymentStep { select, details, confirmation }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isUnauthorizedMsg(String? msg) {
    if (msg == null) return false;
    final m = msg.toLowerCase();
    return m.contains('unauthorized') ||
        m.contains('forbidden') ||
        m.contains('401') ||
        m.contains('403');
  }

  PaymentStep _step = PaymentStep.select;
  final TextEditingController _searchCtrl = TextEditingController();

  DriverSummary? _target;
  int _periods = 1;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _paymentResult;

  static const Color _gradB = Color(0xFF0284c7);

  @override
  void initState() {
    super.initState();
    _autoResolveIfDriver();
  }

  Future<void> _autoResolveIfDriver() async {
    if (currentUser?.userType == 'Driver' && currentUser?.driverId != null) {
      setState(() => _loading = true);
      final res = await resolveDriver(driverId: currentUser!.driverId);
      if (!mounted) return;

      if (res.success && res.data != null) {
        setState(() {
          _target = res.data;
          _periods = 1;
          _step = PaymentStep.details;
          if (_target!.plateNumber != null) {
            _searchCtrl.text = _target!.plateNumber!;
          }
        });
      } else {
        if (!_isUnauthorizedMsg(res.error)) {
          setState(() => _error = res.error ?? 'መረጃ መጫን አልተሳካም።');
        }
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _findDriver() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _target = null;
      _step = PaymentStep.select;
    });

    final res = await resolveDriver(plate: q.toUpperCase());
    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _target = res.data;
        _periods = 1;
        _step = PaymentStep.details;
      });
    } else {
      if (!_isUnauthorizedMsg(res.error)) {
        setState(() => _error = res.error ?? 'መረጃ ማግኘት አልተሳካም።');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  bool _hasOverdue() {
    if (_target == null) return false;
    final todayISO = DateTime.now().toIso8601String().split('T').first;
    final au = _target!.activeUntilDate;
    return (au == null) || (au.compareTo(todayISO) < 0);
  }

  Map<String, dynamic> _coverageGC() {
    if (_target == null) {
      final now = DateTime.now();
      return {'start': now, 'end': now, 'includesPagume': false};
    }

    final overdue = _hasOverdue();
    DateTime base;

    if (overdue) {
      base = DateTime.now();
    } else {
      final au = gcFromIsoLocal(_target!.activeUntilDate!);
      base = au.add(const Duration(days: 1));
    }

    if (_target!.isWeekly) {
      final effectiveWeeks = overdue ? (_periods + 1) : _periods;
      final start = gcWeekStartMonday(base);
      final weeksToShow = effectiveWeeks <= 0 ? 1 : effectiveWeeks;
      final end = gcEndOfDay(start.add(Duration(days: weeksToShow * 7 - 1)));
      return {'start': start, 'end': end, 'includesPagume': false};
    } else {
      final ecBase = ecFromGc(base);
      final start = gcFromEc(ecBase.year, ecBase.month, 1);
      final effectiveMonths = overdue ? (_periods + 1) : _periods;
      final monthsToShow = effectiveMonths <= 0 ? 1 : effectiveMonths;
      final next = ecAddMonths(ecBase.year, ecBase.month, monthsToShow);
      final nextStartGc = gcFromEc(next[0], next[1], 1);
      final end = nextStartGc.subtract(const Duration(milliseconds: 1));
      final includesPagume = ecRangeIncludesNehase(
        ecBase.year,
        ecBase.month,
        monthsToShow,
      );
      return {'start': start, 'end': end, 'includesPagume': includesPagume};
    }
  }

  Map<String, String> _coverageEC() {
    final gc = _coverageGC();
    return {
      'start': ecFormatFullFromGc(gc['start'] as DateTime),
      'end': ecFormatFullFromGc(gc['end'] as DateTime),
    };
  }

  Map<String, num> _totals() {
    if (_target == null) {
      return {
        'base': 0,
        'interest': 0,
        'overdueBase': 0,
        'total': 0,
        'hasOverdue': 0,
        'hasInterest': 0,
      };
    }

    final fee = _target!.policy.planFee;
    final hasOverdue = _hasOverdue();
    final num interest = hasOverdue ? _target!.interestAccrued : 0;
    final num overdueBase = hasOverdue ? fee : 0;
    final num prepayBase = _periods * fee;
    final total = overdueBase + interest + prepayBase;

    return {
      'base': prepayBase,
      'interest': interest,
      'overdueBase': overdueBase,
      'total': total,
      'hasOverdue': hasOverdue ? 1 : 0,
      'hasInterest': (hasOverdue && interest > 0) ? 1 : 0,
    };
  }

  void _reset() {
    setState(() {
      _step = PaymentStep.select;
      _searchCtrl.clear();
      _target = null;
      _periods = 1;
      _error = null;
      _paymentResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals();
    final covGC = _coverageGC();

    final activeUntilEc = _target?.activeUntilDate == null
        ? '—'
        : ecFromIsoShort(_target!.activeUntilDate!);

    return FeatureLayout(
      title: 'ክፍያ',
      icon: Icons.payments_outlined,
      headerChild: _buildHeaderSearchBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            InfoCard(
              color: Colors.red.shade700,
              border: Colors.red.shade200,
              bg: Colors.red.withOpacity(0.06),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          const SizedBox(height: 4),
          if (_step == PaymentStep.details && _target != null) ...[
            _buildPrepaySelector(activeUntilEc),
            const SizedBox(height: 10),
            _buildSummaryCard(totals, covGC),
            const SizedBox(height: 24),
          ],
          if (_step == PaymentStep.confirmation &&
              _paymentResult != null &&
              _target != null) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 6),
                  Text(
                    'ክፍያ ተሳክቷል!',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gradB,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _reset,
                child: Text(
                  'ሌላ ክፍያ ፈጽም',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            onSubmitted: (_) => _findDriver(),
            decoration: InputDecoration(
              hintText: 'ታርጋ ቁጥር ያስገቡ (AA-123456)',
              hintStyle: const TextStyle(color: Colors.white70),
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
            onPressed: _loading ? null : _findDriver,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
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

  Widget _buildPrepaySelector(String activeUntilEc) {
    final ec = _coverageEC();
    final gc = _coverageGC();

    // Small pill-style badge
    Widget planBadge() {
      final isWeekly = _target!.isWeekly;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x334338CA)),
        ),
        child: Text(
          isWeekly ? 'ሳምንታዊ' : 'ወርሃዊ',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4338CA),
          ),
        ),
      );
    }

    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (driver name + plan badge)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _target!.driverName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _gradB, // match driver color to coverage color
                  ),
                ),
              ),
              planBadge(),
            ],
          ),
          const SizedBox(height: 4),

          // Active until date (date first, then text)
          Text(
            '$activeUntilEc ድረስ ከፍለዋል',
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 14),

          // Centered period selector
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SquareIconButton(
                  icon: Icons.remove,
                  onPressed: _periods > 0
                      ? () => setState(() => _periods--)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_periods',
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: _gradB,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _target!.isWeekly ? 'ሳምንት' : 'ወር',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                SquareIconButton(
                  icon: Icons.add,
                  onPressed: () => setState(() => _periods++),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Coverage range
          Text(
            '${ec['start']} → ${ec['end']}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: _gradB,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 6),

          if (!_target!.isWeekly && (gc['includesPagume'] as bool))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'የ ጳጉሜ ቀናትን ይጨምራል',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    Map<String, num> totals,
    Map<String, dynamic> covGC,
  ) {
    final totalPay = totals['total'] ?? 0;

    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title
          Row(
            children: [
              Expanded(
                child: Text(
                  'የክፍያ ማጠቃለያ',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _gradB, // match coverage color
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Breakdown
          row(
            '$_periods ${_target!.isWeekly ? 'ሳምንት' : 'ወር'}',
            '${totals['base']} ETB',
          ),
          if ((totals['hasOverdue'] == 1) && (totals['overdueBase']! > 0))
            rowColored(
              'የዘገየ ክፍያ',
              '+${totals['overdueBase']} ETB',
              Colors.red.shade700,
            ),
          if (totals['hasInterest'] == 1)
            rowColored(
              'የተጠራቀመ ወለድ',
              '+${totals['interest']} ETB',
              Colors.orange.shade700,
            ),

          const Divider(height: 22),

          // Total (a bit bolder)
          rowBold('ጠቅላላ', '${totals['total']} ETB'),

          const SizedBox(height: 12),

          // Pay button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gradB,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loading || totalPay <= 0
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentProvidersScreen(
                            plateNumber: _searchCtrl.text.toUpperCase(),
                            feePlan: _target!.isWeekly ? 'WEEKLY' : 'MONTHLY',
                            prepayQty: _periods,
                            coveredStart: covGC['start'] as DateTime,
                            coveredEnd: covGC['end'] as DateTime,
                            amount: totalPay,
                          ),
                        ),
                      );
                    },
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.credit_card, size: 18),
              label: Text(
                _loading ? '...' : '$totalPay ETB ይከፍሉ',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
