import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../layout/feature_layout.dart';
import '../../../widgets/language_switcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/ethiopian_calendar.dart';
import '../../auth/data/auth_service.dart';
import '../data/payments_api.dart';
import '../models/payment_models.dart';
import 'payment_providers_screen.dart';

import '../../../widgets/common_row.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/square_icon_button.dart';

import '../../../utils/language_helper.dart';

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
  int _periods = 0;
  bool _prepayInitialized = false;
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
          _prepayInitialized = false;
          _periods = 0;
          _step = PaymentStep.details;
          if (_target!.plateNumber != null) {
            _searchCtrl.text = _target!.plateNumber!;
          }
        });
        _initializePrepay();
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
      _prepayInitialized = false;
      _periods = 0;
    });

    final res = await resolveDriver(plate: q.toUpperCase());
    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _target = res.data;
        _step = PaymentStep.details;
      });
      _initializePrepay();
    } else {
      if (!_isUnauthorizedMsg(res.error)) {
        setState(() => _error = res.error ?? 'መረጃ ማግኘት አልተሳካም።');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _initializePrepay() {
    if (_target == null) return;
    if (_prepayInitialized) return;
    final overdue = _hasOverdue();
    setState(() {
      _periods = overdue ? 0 : 1;
      _prepayInitialized = true;
    });
  }

  bool _hasOverdue() {
    if (_target == null) return false;
    final todayISO = DateTime.now().toIso8601String().split('T').first;
    final au = _target!.activeUntilDate;
    return (au == null) || (au.compareTo(todayISO) < 0);
  }

  int _countOverduePeriods() {
    if (_target == null) return 0;
    final au = _target!.activeUntilDate;
    if (au == null) return 1;

    final activeUntil = gcFromIsoLocal(au);
    final today = gcStartOfDay(DateTime.now());
    final anchor = gcStartOfDay(activeUntil);

    if (!anchor.isBefore(today)) return 0;

    if (_target!.isWeekly) {
      final currentMonday = gcWeekStartMonday(today);
      final anchorMonday = gcWeekStartMonday(anchor);
      final diffDays = currentMonday.difference(anchorMonday).inDays;
      final weeks = (diffDays / 7).ceil();
      return weeks < 1 ? 1 : weeks;
    } else {
      final ecAnchor = ecFromGc(anchor);
      final ecToday = ecFromGc(today);
      final monthsDiff =
          (ecToday.year - ecAnchor.year) * 12 +
          (ecToday.month - ecAnchor.month);
      return monthsDiff < 1 ? 1 : monthsDiff;
    }
  }

  DateTime _computeCoverageStart() {
    final au = _target?.activeUntilDate;
    if (au != null && au.isNotEmpty) {
      final activeUntil = gcFromIsoLocal(au);
      return gcStartOfDay(activeUntil.add(const Duration(days: 1)));
    }
    if (_target!.isWeekly) {
      return gcWeekStartMonday(DateTime.now());
    }
    final ecToday = ecFromGc(DateTime.now());
    return gcFromEc(ecToday.year, ecToday.month, 1);
  }

  Map<String, dynamic> _coverageGC() {
    if (_target == null) {
      final now = DateTime.now();
      return {'start': now, 'end': now, 'includesPagume': false};
    }

    final overdue = _hasOverdue();
    final overdueN = overdue ? _countOverduePeriods() : 0;
    final start = _computeCoverageStart();

    if (_target!.isWeekly) {
      final totalPeriods = overdue ? (overdueN + _periods) : _periods;
      final weeksToShow = totalPeriods <= 0 ? 1 : totalPeriods;
      final end = gcEndOfDay(start.add(Duration(days: weeksToShow * 7 - 1)));
      return {'start': start, 'end': end, 'includesPagume': false};
    } else {
      final ecBase = ecFromGc(start);
      final totalPeriods = overdue ? (overdueN + _periods) : _periods;
      final monthsToShow = totalPeriods <= 0 ? 1 : totalPeriods;
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
        'overdueN': 0,
        'total': 0,
        'hasOverdue': 0,
        'hasInterest': 0,
      };
    }

    final fee = _target!.policy.planFee;
    final hasOverdue = _hasOverdue();
    final overdueN = hasOverdue ? _countOverduePeriods() : 0;
    final num interest = hasOverdue ? _target!.interestAccrued : 0;
    final num overdueBase = hasOverdue ? overdueN * fee : 0;
    final num prepayBase = _periods * fee;
    final total = overdueBase + interest + prepayBase;

    return {
      'base': prepayBase,
      'interest': interest,
      'overdueBase': overdueBase,
      'overdueN': overdueN,
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
      _periods = 0;
      _prepayInitialized = false;
      _error = null;
      _paymentResult = null;
    });
  }

  String _getPaidUntilText(AppLocalizations l10n, String? activeUntil) {
    if (activeUntil == null || activeUntil.isEmpty) {
      return l10n.noPayment;
    }
    final ecDate = ecFromIsoShort(activeUntil);
    return '$ecDate ${l10n.paidUntil}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totals = _totals();
    final covGC = _coverageGC();

    return FeatureLayout(
      title: l10n.payments,
      icon: Icons.payments_outlined,
      headerChild: _buildHeaderSearchBar(l10n),
      headerActions: LanguageSwitcher(
        onLanguageSelected: (String languageCode) {
          LanguageHelper.changeLanguage(context, languageCode);
        },
      ),
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
            _buildPrepaySelector(l10n),
            const SizedBox(height: 10),
            _buildSummaryCard(totals, covGC, l10n),
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
                    l10n.pay,
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
                  l10n.pay,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSearchBar(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            onSubmitted: (_) => _findDriver(),
            decoration: InputDecoration(
              hintText: l10n.searchPlate,
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

  Widget _buildPrepaySelector(AppLocalizations l10n) {
    final ec = _coverageEC();
    final gc = _coverageGC();
    final paidUntilText = _getPaidUntilText(l10n, _target!.activeUntilDate);
    final hasPayment =
        _target!.activeUntilDate != null &&
        _target!.activeUntilDate!.isNotEmpty;

    Widget planBadge() {
      final isWeekly = _target!.isWeekly;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50.withOpacity(0.3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x334338CA)),
        ),
        child: Text(
          isWeekly ? l10n.weekly : l10n.monthly,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4338CA),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _target!.driverName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _gradB,
                    ),
                  ),
                ),
                planBadge(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              paidUntilText,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: hasPayment ? Colors.black54 : Colors.red.shade700,
                fontWeight: hasPayment ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
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
                          _target!.isWeekly ? l10n.week : l10n.month,
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
      ),
    );
  }

  Widget _buildSummaryCard(
    Map<String, num> totals,
    Map<String, dynamic> covGC,
    AppLocalizations l10n,
  ) {
    final totalPay = totals['total'] ?? 0;
    final overdueN = (totals['overdueN'] ?? 0).toInt();

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.feeSummary,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _gradB,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_periods > 0)
              row(
                '$_periods ${_target!.isWeekly ? l10n.week : l10n.month}',
                '${totals['base']} ETB',
              ),
            if ((totals['hasOverdue'] == 1) && (totals['overdueBase']! > 0))
              rowColored(
                '$overdueN ${_target!.isWeekly ? l10n.week : l10n.month} ${l10n.overdue}',
                '+${totals['overdueBase']} ETB',
                Colors.red.shade700,
              ),
            if (totals['hasInterest'] == 1)
              rowColored(
                l10n.interest,
                '+${totals['interest']} ETB',
                Colors.orange.shade700,
              ),
            const Divider(height: 22),
            rowBold(l10n.total, '${totals['total']} ETB'),
            const SizedBox(height: 12),
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
                  _loading ? '...' : '$totalPay ETB ${l10n.pay}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
