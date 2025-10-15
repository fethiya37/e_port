import 'dart:convert';
import 'package:e_port/core/config.dart';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart'; // for authToken
import '../models/payment_models.dart'; // ✅ new import

String _errFromResp(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    return (j['message'] ?? j['error'] ?? 'HTTP ${r.statusCode}').toString();
  } catch (_) {
    return 'HTTP ${r.statusCode}';
  }
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
    throw Exception('የኔትዎርክ ችግር። እባክዎ ደግመው ይሞክሩ።');
  }
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

    if (r.statusCode >= 200 && r.statusCode < 300) {
      Map<String, dynamic>? body;
      if (r.body.isNotEmpty) {
        try {
          final j = jsonDecode(r.body) as Map<String, dynamic>;
          body = (j['payment'] ?? j) as Map<String, dynamic>;
        } catch (_) {}
      }
      return ApplyPaymentResult.success(body);
    }
    return ApplyPaymentResult.error(_errFromResp(r));
  } catch (_) {
    return const ApplyPaymentResult(
      success: false,
      error: 'የኔትዎርክ ችግር። እባክዎ ደግመው ይሞክሩ።',
    );
  }
}
