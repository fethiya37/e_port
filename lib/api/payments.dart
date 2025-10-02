import 'dart:convert';
import 'package:e_port/core/config.dart';
import 'package:http/http.dart' as http;
import '../utils/auth.dart';

String _errFromResp(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    return (j['message'] ?? j['error'] ?? 'HTTP ${r.statusCode}').toString();
  } catch (_) {
    return 'HTTP ${r.statusCode}';
  }
}

/// Policy that comes WITH the driver resolve (already matched to the plan).
class DriverPolicy {
  final num planFee; // weekly fee if weekly driver else monthly fee
  final num dailyFinePercent; // e.g. 0.2 => 20%
  const DriverPolicy({required this.planFee, required this.dailyFinePercent});

  factory DriverPolicy.fromJson(Map<String, dynamic> j) => DriverPolicy(
    planFee: (j['plan_fee'] ?? j['planFee'] ?? 0) as num,
    dailyFinePercent:
        (j['daily_fine_percent'] ?? j['dailyFinePercent'] ?? 0) as num,
  );
}

class DriverSummary {
  final String associationName;
  final String driverName;
  final String? plateNumber;
  final bool isWeekly;
  final String? activeUntilDate; // ISO (GC) "YYYY-MM-DD"
  final num interestAccrued;
  final DriverPolicy policy;

  const DriverSummary({
    required this.associationName,
    required this.driverName,
    required this.plateNumber,
    required this.isWeekly,
    required this.activeUntilDate,
    required this.interestAccrued,
    required this.policy,
  });

  factory DriverSummary.fromJson(Map<String, dynamic> j) => DriverSummary(
    associationName: (j['association_name'] ?? '') as String,
    driverName: (j['driver_name'] ?? '') as String,
    plateNumber: j['plate_number'] as String?,
    isWeekly: (j['is_weekly'] ?? false) as bool,
    activeUntilDate:
        (j['active_until_date'] ?? j['activeUntilDate']) as String?,
    interestAccrued:
        (j['interest_accrued'] ?? j['interestAccrued'] ?? 0) as num,
    policy: DriverPolicy.fromJson((j['policy'] ?? {}) as Map<String, dynamic>),
  );
}

/// Resolve driver for payment (by plate or driver_id)
Future<DriverSummary> resolveDriver({String? plate, int? driverId}) async {
  if ((plate == null || plate.isEmpty) && driverId == null) {
    throw Exception('Provide plate or driver_id');
  }

  final qs = plate != null ? 'plate=$plate' : 'driver_id=$driverId';
  final url = Uri.parse('${AppConfig.baseUrl}/vehicles/resolve?$qs');

  final headers = <String, String>{};
  if (authToken != null) headers['Authorization'] = 'Bearer $authToken';

  try {
    final r = await http.get(url, headers: headers);

    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final inner = (j['vehicle_payment'] ?? j) as Map<String, dynamic>;
      return DriverSummary.fromJson(inner);
    }
    throw Exception(_errFromResp(r));
  } catch (_) {
    throw Exception('የኔትዎርክ ችግኝ። እባክዎ ደግመው ይሞክሩ።');
  }
}

/// Apply payment result wrapper
class ApplyPaymentResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? body;
  const ApplyPaymentResult({required this.success, this.error, this.body});
}

/// Apply payment request → matches PayDto
Future<ApplyPaymentResult> applyPayment({
  int? driverId,
  String? plateNumber,
  required String feePlan,
  required int prepayQty,
  required DateTime coveredStart,
  required DateTime coveredEnd,
  num? amount,
}) async {
  final url = Uri.parse('${AppConfig.baseUrl}/payments/apply');

  final payload = {
    if (driverId != null) 'driver_id': driverId,
    if (plateNumber != null) 'plate_number': plateNumber,
    'fee_plan': feePlan,
    'prepaid_qty': prepayQty,
    'covered_start_date': coveredStart.toIso8601String(),
    'covered_end_date': coveredEnd.toIso8601String(),
    if (amount != null) 'amount': amount,
    'payment_method': 'MOBILE',
  };

  try {
    final r = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(payload),
    );

    final is2xx = r.statusCode >= 200 && r.statusCode < 300;
    if (is2xx) {
      Map<String, dynamic>? body;
      if (r.body.isNotEmpty) {
        try {
          final j = jsonDecode(r.body) as Map<String, dynamic>;
          body = (j['payment'] ?? j) as Map<String, dynamic>;
        } catch (_) {}
      }
      return ApplyPaymentResult(success: true, body: body);
    }
    return ApplyPaymentResult(success: false, error: _errFromResp(r));
  } catch (_) {
    return ApplyPaymentResult(
      success: false,
      error: 'የኔትዎርክ ችግኝ። እባክዎ ደግመው ይሞክሩ።',
    );
  }
}
