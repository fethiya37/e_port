import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../layout/feature_layout.dart';
import '../../../utils/ethiopian_calendar.dart';
import '../../auth/data/auth_service.dart';
import '../data/payments_api.dart';
import '../models/payment_models.dart';

// ✅ reusable widgets
import '../../../widgets/driver_card.dart';
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
  PaymentStep step = PaymentStep.select;
  final _searchCtrl = TextEditingController();

  DriverSummary? target;
  int periods = 0;
  bool loading = false;
  String? error;
  Map<String, dynamic>? paymentResult;

  static const _gradB = Color(0xFF0284c7);

  @override
  void initState() {
    super.initState();
    _autoResolveIfDriver();
  }

  /// 🔑 Auto-resolve if logged-in user is a Driver
  Future<void> _autoResolveIfDriver() async {
    if (currentUser?.userType == 'Driver' && currentUser?.driverId != null) {
      setState(() => loading = true);
      try {
        final d = await resolveDriver(driverId: currentUser!.driverId);
        setState(() {
          target = d;
          periods = 0;
          step = PaymentStep.details;
          if (d.plateNumber != null) _searchCtrl.text = d.plateNumber!;
        });
      } catch (e) {
        setState(() => error = e.toString());
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  // ===== Actions =====
  Future<void> _findDriver() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      loading = true;
      error = null;
      target = null;
      step = PaymentStep.select;
    });

    try {
      final d = await resolveDriver(plate: q.toUpperCase());
      setState(() {
        target = d;
        periods = 0;
        step = PaymentStep.details;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _hasOverdue() {
    if (target == null) return false;
    final todayISO = DateTime.now().toIso8601String().split('T').first;
    final au = target!.activeUntilDate;
    return au == null || au.compareTo(todayISO) < 0;
  }

  Map<String, dynamic> _coverageGC() {
    if (target == null) {
      final now = DateTime.now();
      return {'start': now, 'end': now, 'includesPagume': false};
    }

    final overdue = _hasOverdue();
    DateTime base;

    if (overdue) {
      base = DateTime.now();
    } else {
      final au = gcFromIsoLocal(target!.activeUntilDate!);
      base = au.add(const Duration(days: 1));
    }

    if (target!.isWeekly) {
      final effectiveWeeks = overdue ? (periods + 1) : periods;
      final start = gcWeekStartMonday(base);
      final weeksToShow = effectiveWeeks <= 0 ? 1 : effectiveWeeks;
      final end = gcEndOfDay(start.add(Duration(days: weeksToShow * 7 - 1)));
      return {'start': start, 'end': end, 'includesPagume': false};
    } else {
      final ecBase = ecFromGc(base);
      final start = gcFromEc(ecBase.year, ecBase.month, 1);
      final effectiveMonths = overdue ? (periods + 1) : periods;
      final monthsToShow = effectiveMonths <= 0 ? 1 : effectiveMonths;
      final next = ecAddMonths(ecBase.year, ecBase.month, monthsToShow);
      final nextStartGc = gcFromEc(next[0], next[1], 1);
      final end = nextStartGc.subtract(const Duration(milliseconds: 1));
      final includesPagume =
          ecRangeIncludesNehase(ecBase.year, ecBase.month, monthsToShow);
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
    if (target == null) {
      return {
        'base': 0,
        'interest': 0,
        'overdueBase': 0,
        'total': 0,
        'hasOverdue': 0,
        'hasInterest': 0,
      };
    }

    final fee = target!.policy.planFee;
    final hasOverdue = _hasOverdue();
    final num interest = hasOverdue ? target!.interestAccrued : 0;
    final num overdueBase = hasOverdue ? fee : 0;
    final num prepayBase = periods * fee;
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

  Future<void> _pay() async {
    if (target == null) return;
    setState(() {
      loading = true;
      error = null;
    });

    final totals = _totals();
    final cov = _coverageGC();

    try {
      final res = await applyPayment(
        plateNumber: _searchCtrl.text.toUpperCase(),
        feePlan: target!.isWeekly ? 'WEEKLY' : 'MONTHLY',
        prepayQty: periods,
        coveredStart: cov['start'] as DateTime,
        coveredEnd: cov['end'] as DateTime,
        amount: totals['total'],
      );
      if (res.success) {
        setState(() {
          paymentResult = res.body;
          step = PaymentStep.confirmation;
        });
      } else {
        setState(() => error = res.error ?? 'Payment failed');
      }
    } catch (_) {
      setState(() => error = 'Payment processing failed');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() {
    setState(() {
      step = PaymentStep.select;
      _searchCtrl.clear();
      target = null;
      periods = 0;
      error = null;
      paymentResult = null;
    });
  }

  // ===== Build =====
  @override
  Widget build(BuildContext context) {
    final totals = _totals();
    final coverageEC = _coverageEC();
    final covGC = _coverageGC();

    final activeUntilEc = target?.activeUntilDate == null
        ? '—'
        : ecFromIsoShort(target!.activeUntilDate!);

    return FeatureLayout(
      title: 'ክፍያ',
      icon: Icons.payments_outlined,
      headerChild: _buildHeaderSearchBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            InfoCard(
              color: Colors.red.shade700,
              border: Colors.red.shade200,
              bg: Colors.red.withOpacity(0.06),
              child: Text(error!, style: const TextStyle(color: Colors.black87)),
            ),

          // ===== Details Step =====
          if (step == PaymentStep.details && target != null) ...[
            DriverCard(
              name: target!.driverName,
              planLabel: target!.isWeekly ? 'ሳምንታዊ' : 'ወርሃዊ',
              activeUntilEc: activeUntilEc,
              interestAccrued: target!.interestAccrued.toStringAsFixed(2),
            ),

            // ===== Prepay selector =====
            WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ቅድመ ክፍያ',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A))),
                  Text('ለቀጣይ ${target!.isWeekly ? 'ሳምንታት' : 'ወራት'} ',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SquareIconButton(
                        icon: Icons.remove,
                        onPressed:
                            periods > 0 ? () => setState(() => periods--) : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Text(
                              '$periods',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: _gradB,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(target!.isWeekly ? 'ሳምንት' : 'ወር',
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      SquareIconButton(
                        icon: Icons.add,
                        onPressed: () => setState(() => periods++),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ===== Coverage preview =====
            WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('የ ክፍያ ክፍለ ጊዜ',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text('${coverageEC['start']} → ${coverageEC['end']}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: _gradB)),
                  const SizedBox(height: 6),
                  Text('የ • $periods ${target!.isWeekly ? 'ሳምንት' : 'ወር'} ክፍለ ጊዜ',
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  if (!target!.isWeekly && (covGC['includesPagume'] as bool))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('የ ጳጉሜ ቀናትን ይጨምራል',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ),
                ],
              ),
            ),

            // ===== Summary =====
            WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('የክፍያ ማጠቃለያ',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  row('$periods ${target!.isWeekly ? 'ሳምንት' : 'ወር'}',
                      '${(totals['base'] ?? 0)} ETB'),
                  if ((totals['hasOverdue'] == 1) &&
                      (totals['overdueBase'] ?? 0) > 0)
                    rowColored('የዘገየ ክፍያ',
                        '+${totals['overdueBase']} ETB', Colors.red.shade700),
                  if (totals['hasInterest'] == 1)
                    rowColored('የተጠራቀመ ወለድ',
                        '+${totals['interest']} ETB', Colors.orange.shade700),
                  const Divider(height: 20),
                  rowBold('ጠቅላላ', '${totals['total']} ETB'),
                ],
              ),
            ),

            // ===== Pay Button =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gradB,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: loading || (totals['total'] ?? 0) <= 0 ? null : _pay,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.credit_card),
                label: Text(
                  loading
                      ? 'የክፍያ ሂደት በሂደት ይገኛል...'
                      : '${totals['total']} ETB ይከፍሉ',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          // ===== Confirmation Step =====
          if (step == PaymentStep.confirmation &&
              paymentResult != null &&
              target != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 6),
                  Text('ክፍያ ተሳክቷል!',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            WhiteCard(
              child: Column(
                children: [
                  row('አሽከርካሪ', target!.driverName),
                  row('ክፍያ', target!.isWeekly ? 'Weekly' : 'Monthly'),
                  row('የተከፈለው ክፍለ ጊዜ', '$periods'),
                  rowBold(
                      'አጠቃላይ ክፍያ',
                      '${paymentResult!['breakdown']?['total'] ?? paymentResult!['total_paid'] ?? ''} ETB'),
                  if ((paymentResult!['breakdown']?['interest'] ??
                          paymentResult!['interest_cleared'] ??
                          0) >
                      0)
                    rowColored(
                        'የተሰረዘ ወለድ',
                        '-${paymentResult!['breakdown']?['interest'] ?? paymentResult!['interest_cleared']} ETB',
                        Colors.green.shade700),
                  const Divider(height: 20),
                  Builder(builder: (_) {
                    final isoFrom =
                        paymentResult!['coverage']?['from'] as String?;
                    final isoTo =
                        paymentResult!['coverage']?['to'] as String?;
                    final ecFrom = (isoFrom == null || isoFrom.isEmpty)
                        ? '—'
                        : ecFromIsoShort(isoFrom);
                    final ecTo = (isoTo == null || isoTo.isEmpty)
                        ? '—'
                        : ecFromIsoShort(isoTo);
                    return row('የተከፈለበት ጊዜ', '$ecFrom → $ecTo');
                  }),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _gradB, foregroundColor: Colors.white),
                onPressed: _reset,
                child: const Text('ሌላ ክፍያ ፈጽም'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== Header Search Bar =====
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
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
            onPressed: loading ? null : _findDriver,
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
}
