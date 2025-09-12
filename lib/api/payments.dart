// lib/api/payments.dart
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
  final num planFee;           // weekly fee if weekly driver else monthly fee
  final num dailyFinePercent;  // e.g. 0.2 => 20%
  const DriverPolicy({required this.planFee, required this.dailyFinePercent});

  factory DriverPolicy.fromJson(Map<String, dynamic> j) => DriverPolicy(
        planFee: (j['plan_fee'] ?? j['planFee'] ?? 0) as num,
        dailyFinePercent:
            (j['daily_fine_percent'] ?? j['dailyFinePercent'] ?? 0) as num,
      );
}

class DriverSummary {
  final int id;
  final String name;
  final String phone;
  final bool isWeekly;
  final String? activeUntilDate; // ISO (GC) "YYYY-MM-DD" from server
  final num interestAccrued;
  final DriverPolicy policy;

  const DriverSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.isWeekly,
    required this.activeUntilDate,
    required this.interestAccrued,
    required this.policy,
  });

  factory DriverSummary.fromJson(Map<String, dynamic> j) => DriverSummary(
        id: j['id'] as int,
        name: (j['full_name'] ?? j['name'] ?? '') as String,
        phone: (j['phone_number'] ?? j['phone'] ?? '') as String,
        isWeekly: (j['is_weekly'] ?? j['isWeekly'] ?? false) as bool,
        activeUntilDate:
            (j['active_until_date'] ?? j['activeUntilDate']) as String?,
        interestAccrued:
            (j['interest_accrued'] ?? j['interestAccrued'] ?? 0) as num,
        policy: DriverPolicy.fromJson((j['policy'] ?? {}) as Map<String, dynamic>),
      );
}

/// Resolve driver by plate OR phone (backend scopes association & ensures active pair for plate)
Future<DriverSummary> resolveDriver({String? plate, String? phone}) async {
  if ((plate == null || plate.isEmpty) && (phone == null || phone.isEmpty)) {
    throw Exception('Provide plate or phone');
  }
  final qs = plate != null ? 'plate=$plate' : 'phone=$phone';
  final url = Uri.parse('${AppConfig.baseUrl}/drivers/resolve?$qs');
  final r = await http.get(url, headers: {'Authorization': 'Bearer $authToken'});

  if (r.statusCode == 200) {
    return DriverSummary.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
  throw Exception(_errFromResp(r));
}

/// Apply payment
class ApplyPaymentResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? body;
  const ApplyPaymentResult({required this.success, this.error, this.body});
}
Future<ApplyPaymentResult> applyPayment({
  required int driverId,
  required bool isWeekly,            // NEW
  required int prepayQty,
  required DateTime coveredStart,    // NEW
  required DateTime coveredEnd,      // NEW
  String? plateNumber,
  num? totalOverride,
}) async {
  final url = Uri.parse('${AppConfig.baseUrl}/payments/apply');
  final payload = {
    'driver_id': driverId,
    'is_weekly': isWeekly, // NEW
    if (plateNumber != null) 'plate_number': plateNumber,
    'prepay_qty': prepayQty,
    'covered_start_date': coveredStart.toUtc().toIso8601String(), // NEW
    'covered_end_date': coveredEnd.toUtc().toIso8601String(),     // NEW
    if (totalOverride != null) 'total_override': totalOverride,
  };

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
      try { body = jsonDecode(r.body) as Map<String, dynamic>; } catch (_) {}
    }
    return ApplyPaymentResult(success: true, body: body);
  }
  return ApplyPaymentResult(success: false, error: _errFromResp(r));
}
