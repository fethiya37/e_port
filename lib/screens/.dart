// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/payments.dart';
import '../utils/ethiopian_calendar.dart';

enum PaymentStep { select, details, confirmation }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // ====== UI constants (match RouteAssignments UI) ======
  static const _gradA = Color(0xFF0ea5e9); // Sky 500
  static const _gradB = Color(0xFF0284c7); // Sky 600
  static const _gradC = Color(0xFF0c4a6e); // Sky 900

  PaymentStep step = PaymentStep.select;
  final _searchCtrl = TextEditingController();

  DriverSummary? target;
  int periods = 0; // prepay periods
  bool loading = false;
  String? error;
  Map<String, dynamic>? paymentResult;

  // ====== Actions ======
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
        periods = 0; // reset selection
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
    final today = DateTime.now();
    final todayISO = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String().split('T').first;
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
    final startEc = ecFormatFullFromGc(gc['start'] as DateTime);
    final endEc = ecFormatFullFromGc(gc['end'] as DateTime);
    return {'start': startEc, 'end': endEc};
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

    final num interest = hasOverdue ? (target!.interestAccrued) : 0;
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
    final plateMaybe = _searchCtrl.text.toUpperCase();
    final cov = _coverageGC();

    try {
      final res = await applyPayment(
        driverName: target!.driverName,
        isWeekly: target!.isWeekly,
        prepayQty: periods,
        coveredStart: cov['start'] as DateTime,
        coveredEnd: cov['end'] as DateTime,
        plateNumber: plateMaybe,
        totalOverride: totals['total'] ?? 0,
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final safeTop = mq.padding.top;
    final headerH = (h * 0.20).clamp(180.0, 240.0);

    final totals = _totals();
    final coverageEC = _coverageEC();
    final covGC = _coverageGC();

    final activeUntilEc = target?.activeUntilDate == null
        ? '—'
        : ecFromIsoShort(target!.activeUntilDate!);

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
            // ===== Header =====
            Container(
              height: headerH,
              padding: EdgeInsets.fromLTRB(20, safeTop + 12, 20, 20),
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Payment',
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
                          onSubmitted: (_) => _findDriver(),
                          decoration: InputDecoration(
                            hintText: 'Enter plate (AA-123456)',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white70,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white70,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1.2,
                              ),
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
                              side: const BorderSide(
                                color: Colors.white70,
                                width: 1,
                              ),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
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

            // ===== White sheet =====
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
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
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),

                        if (step == PaymentStep.details && target != null) ...[
                          _DriverCard(
                            name: target!.driverName,
                            planLabel: target!.isWeekly ? 'Weekly' : 'Monthly',
                            activeUntilEc: activeUntilEc,
                            interestAccrued: target!.interestAccrued
                                .toStringAsFixed(2),
                          ),

                          // Prepay selector
                          _WhiteCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prepay Periods',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Pay for future ${target!.isWeekly ? 'weeks' : 'months'}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _SquareIconButton(
                                      icon: Icons.remove,
                                      onPressed: periods > 0
                                          ? () => setState(() => periods--)
                                          : null,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
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
                                          Text(
                                            target!.isWeekly
                                                ? 'weeks'
                                                : 'months',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _SquareIconButton(
                                      icon: Icons.add,
                                      onPressed: () =>
                                          setState(() => periods++),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Coverage preview
                          Builder(
                            builder: (_) {
                              final ec = coverageEC;
                              return _WhiteCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'New Coverage Period (EC)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${ec['start']} → ${ec['end']}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: _gradB,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ethiopian Calendar • $periods ${target!.isWeekly ? 'weeks' : 'months'} coverage',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (!target!.isWeekly &&
                                        (covGC['includesPagume'] as bool))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          'Includes Pagume (ጳጉሜ) days',
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
                            },
                          ),

                          // Summary
                          _WhiteCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Summary',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _row(
                                  'Base ($periods ${target!.isWeekly ? 'weeks' : 'months'})',
                                  '${(totals['base'] ?? 0)} ETB',
                                ),
                                if ((totals['hasOverdue'] == 1) &&
                                    (totals['overdueBase'] ?? 0) > 0)
                                  _rowColored(
                                    'Overdue base (current period)',
                                    '+${totals['overdueBase']} ETB',
                                    Colors.red.shade700,
                                  ),
                                if (totals['hasInterest'] == 1)
                                  _rowColored(
                                    'Interest accrued',
                                    '+${totals['interest']} ETB',
                                    Colors.orange.shade700,
                                  ),
                                const Divider(height: 20),
                                _rowBold('Total', '${totals['total']} ETB'),
                              ],
                            ),
                          ),

                          // Pay button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _gradB,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: loading || (totals['total'] ?? 0) <= 0
                                  ? null
                                  : _pay,
                              icon: loading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.credit_card),
                              label: Text(
                                loading
                                    ? 'Processing Payment...'
                                    : 'Pay ${totals['total']} ETB',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (step == PaymentStep.confirmation &&
                            paymentResult != null &&
                            target != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Payment Successful!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _WhiteCard(
                            child: Column(
                              children: [
                                _row('Driver', target!.driverName),
                                _row(
                                  'Plan',
                                  target!.isWeekly ? 'Weekly' : 'Monthly',
                                ),
                                _row('Periods paid', '$periods'),
                                _rowBold(
                                  'Total paid',
                                  '${paymentResult!['breakdown']?['total'] ?? paymentResult!['total_paid'] ?? ''} ETB',
                                ),
                                if ((paymentResult!['breakdown']?['interest'] ??
                                        paymentResult!['interest_cleared'] ??
                                        0) >
                                    0)
                                  _rowColored(
                                    'Interest cleared',
                                    '-${paymentResult!['breakdown']?['interest'] ?? paymentResult!['interest_cleared']} ETB',
                                    Colors.green.shade700,
                                  ),
                                const Divider(height: 20),
                                Builder(
                                  builder: (_) {
                                    final isoTo =
                                        paymentResult!['coverage']?['to']
                                            as String?;
                                    String ecOut;
                                    if (isoTo != null) {
                                      ecOut = ecFromIsoShort(isoTo);
                                    } else {
                                      final alt =
                                          paymentResult!['new_active_until_date']
                                              ?.toString();
                                      ecOut = alt == null || alt.isEmpty
                                          ? '—'
                                          : ecFromIsoShort(alt);
                                    }
                                    return _rowBold(
                                      'New coverage until',
                                      ecOut,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _gradB,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _reset,
                              child: const Text('Make Another Payment'),
                            ),
                          ),
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

  // ===== UI helpers =====
  Widget _row(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(a), Text(b)],
    ),
  );

  Widget _rowBold(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        Text(b, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _rowColored(String a, String b, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a, style: TextStyle(color: c)),
        Text(b, style: TextStyle(color: c)),
      ],
    ),
  );
}

// ===== Cards =====

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
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: color),
        child: child,
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});
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
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _PaymentScreenState._gradB,
          side: const BorderSide(color: _PaymentScreenState._gradB, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.name,
    required this.planLabel,
    required this.activeUntilEc,
    required this.interestAccrued,
  });

  final String name;
  final String planLabel;
  final String activeUntilEc; // EC
  final String interestAccrued;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with plan chip
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _PaymentScreenState._gradB.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _PaymentScreenState._gradB.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  planLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _PaymentScreenState._gradB,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _kv('Active Until (EC)', activeUntilEc)),
              const SizedBox(width: 12),
              Expanded(child: _kv('Interest Accrued', '$interestAccrued ETB')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 2),
      Text(v, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
    ],
  );
}
