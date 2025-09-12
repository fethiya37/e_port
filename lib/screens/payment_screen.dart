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
  PaymentStep step = PaymentStep.select;
  final _searchCtrl = TextEditingController();

  DriverSummary? target;
  int periods = 0; // prepay periods
  bool loading = false;
  String? error;
  Map<String, dynamic>? paymentResult;

  Future<void> _findDriver() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      target = null;
    });
    try {
      final plateLike =
          q.contains('-') || RegExp(r'^[A-Z]{2}-\d{5,6}$').hasMatch(q);
      final d = plateLike
          ? await resolveDriver(plate: q.toUpperCase())
          : await resolveDriver(phone: q);
      setState(() {
        target = d;
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

  /// Coverage math with **EC-correct** boundaries.
  /// Weekly:
  ///   - overdue/null: start = current EC week Monday (GC) ; end = Sunday of N-th week
  ///   - active: start = EC week Monday containing (active_until + 1d)
  /// Monthly:
  ///   - start = EC day 1 of current (or next) EC month
  ///   - end   = (next EC month day 1 after +N months) - 1 day (includes Pagume after Nehase)
  ///
  /// Returns {start: GC, end: GC, includesPagume: bool}
  Map<String, dynamic> _coverageGC() {
    if (target == null) {
      final now = DateTime.now();
      return {'start': now, 'end': now, 'includesPagume': false};
    }

    final overdue = _hasOverdue();

    // base date = today (if overdue) OR (active_until + 1 day) (if still active)
    DateTime base;
    if (overdue) {
      base = DateTime.now();
    } else {
      // active_until_date is GC ISO "YYYY-MM-DD" (00:00 local)
      final au = gcFromIsoLocal(target!.activeUntilDate!);
      base = au.add(const Duration(days: 1));
    }

    if (target!.isWeekly) {
      // Effective number of weeks to cover on the UI preview:
      // - overdue => include current week => periods + 1
      // - not overdue => periods
      final effectiveWeeks = overdue ? (periods + 1) : periods;

      // Start is Monday of the EC week that contains `base` (done via GC helper)
      final start = gcWeekStartMonday(base);

      // If effective is 0 (no overdue & no prepay), still show one full week window for clarity
      final weeksToShow = effectiveWeeks <= 0 ? 1 : effectiveWeeks;

      final end = gcEndOfDay(start.add(Duration(days: weeksToShow * 7 - 1)));
      return {'start': start, 'end': end, 'includesPagume': false};
    } else {
      // MONTHLY
      // Convert base to EC, then start at the 1st of that EC month
      final ecBase = ecFromGc(base);
      final start = gcFromEc(ecBase.year, ecBase.month, 1);

      // Effective months:
      // - overdue => include current EC month => periods + 1
      // - not overdue => periods
      final effectiveMonths = overdue ? (periods + 1) : periods;

      final monthsToShow = effectiveMonths <= 0 ? 1 : effectiveMonths;

      // End is the day before the first day of the EC month after `monthsToShow`
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

  /// EC pretty for UI
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

    final fee =
        target!.policy.planFee; // weekly fee if weekly, monthly if monthly
    final hasOverdue = _hasOverdue();

    final num interest = hasOverdue ? (target!.interestAccrued) : 0;
    final num overdueBase = hasOverdue
        ? fee
        : 0; // fee is always due for overdue period
    final num prepayBase = periods * fee; // prepay can be 0

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
    final plateMaybe = _searchCtrl.text.contains('-')
        ? _searchCtrl.text.toUpperCase()
        : null;
    final cov = _coverageGC(); // returns {'start': DateTime, 'end': DateTime}

    try {
      final res = await applyPayment(
        driverId: target!.id,
        isWeekly: target!.isWeekly, // NEW
        prepayQty: periods,
        coveredStart: cov['start'] as DateTime, // NEW
        coveredEnd: cov['end'] as DateTime, // NEW
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
    final totals = _totals();
    final coverageEC = _coverageEC();
    final covGC = _coverageGC();

    const blue = Color(0xFF2563EB);
    final headerTitleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
    final titleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0F172A),
    );

    final activeUntilEc = target?.activeUntilDate == null
        ? '—'
        : ecFromIsoShort(target!.activeUntilDate!);

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
                  if (step != PaymentStep.select)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: step == PaymentStep.confirmation
                            ? _reset
                            : () => setState(() => step = PaymentStep.select),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text(''),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  Text('Payment', style: headerTitleStyle),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (error != null)
                    _WhiteCard(
                      child: Text(
                        error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      borderColor: Colors.red.shade200,
                      bgColor: Colors.red.withOpacity(0.06),
                    ),

                  // SELECT
                  if (step == PaymentStep.select) ...[
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Find Driver', style: titleStyle),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter plate number or phone number',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
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
                                    onSubmitted: (_) => _findDriver(),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'AA-123456 or +251911234567',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.search,
                                          color: Colors.black54,
                                        ),
                                  onPressed:
                                      loading || _searchCtrl.text.trim().isEmpty
                                      ? null
                                      : _findDriver,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // DETAILS
                  if (step == PaymentStep.details && target != null) ...[
                    _BlueTopCard(
                      name: target!.name,
                      phone: target!.phone,
                      planLabel: target!.isWeekly ? 'Weekly' : 'Monthly',
                      activeUntilEc: activeUntilEc,
                      interestAccrued: target!.interestAccrued.toStringAsFixed(
                        2,
                      ),
                    ),

                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prepay Periods', style: titleStyle),
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
                                blueBorder: true,
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
                                        color: blue,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      target!.isWeekly ? 'weeks' : 'months',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SquareIconButton(
                                icon: Icons.add,
                                onPressed: () => setState(() => periods++),
                                blueBorder: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Coverage preview (EC)
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CoverageBlock(
                            titleStyle: titleStyle,
                            coverageText:
                                '${coverageEC['start']} → ${coverageEC['end']}',
                            periodsText:
                                'Ethiopian Calendar • $periods ${target!.isWeekly ? 'weeks' : 'months'} coverage',
                          ),
                          if (!target!.isWeekly &&
                              (covGC['includesPagume'] as bool))
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
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
                    ),

                    // Summary
                    _WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Summary', style: titleStyle),
                          const SizedBox(height: 12),
                          _row(
                            'Base (${periods} ${target!.isWeekly ? 'weeks' : 'months'})',
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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
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

                  // CONFIRMATION
                  if (step == PaymentStep.confirmation &&
                      paymentResult != null &&
                      target != null) ...[
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment Successful!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WhiteCard(
                      child: Column(
                        children: [
                          _row('Driver', target!.name),
                          _row('Plan', target!.isWeekly ? 'Weekly' : 'Monthly'),
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

                          // Show new coverage end in EC
                          Builder(
                            builder: (_) {
                              final isoTo =
                                  paymentResult!['coverage']?['to'] as String?;
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
                              return _rowBold('New coverage until', ecOut);
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _reset,
                        child: const Text('Make Another Payment'),
                      ),
                    ),
                  ],
                ],
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

// ===== Presentational widgets =====

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.borderColor, this.bgColor});
  final Widget child;
  final Color? borderColor;
  final Color? bgColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
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

class _BlueTopCard extends StatelessWidget {
  const _BlueTopCard({
    required this.name,
    required this.phone,
    required this.planLabel,
    required this.activeUntilEc, // EC string
    required this.interestAccrued,
  });

  final String name;
  final String phone;
  final String planLabel;
  final String activeUntilEc; // EC!
  final String interestAccrued;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  planLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(phone, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _info('Active Until (EC)', activeUntilEc)),
              const SizedBox(width: 12),
              Expanded(
                child: _info('Interest Accrued', '$interestAccrued ETB'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text(
        v,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    this.onPressed,
    this.blueBorder = false,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final bool blueBorder;
  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF2563EB);
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: blue,
          side: BorderSide(color: blue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _CoverageBlock extends StatelessWidget {
  const _CoverageBlock({
    required this.coverageText,
    required this.periodsText,
    required this.titleStyle,
  });
  final String coverageText;
  final String periodsText;
  final TextStyle titleStyle;
  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New Coverage Period (EC)', style: titleStyle),
        const SizedBox(height: 12),
        Text(
          coverageText,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: blue),
        ),
        const SizedBox(height: 6),
        Text(
          periodsText,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}
