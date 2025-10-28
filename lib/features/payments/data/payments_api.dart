import 'dart:convert';
import 'package:e_port/core/config.dart';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart';
import '../models/payment_models.dart';

/// Utility: extract readable error message
String _errFromResp(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    return (j['message'] ?? j['error'] ?? 'HTTP ${r.statusCode}').toString();
  } catch (_) {
    return 'HTTP ${r.statusCode}';
  }
}

/// ✅ Resolve driver information for payment
Future<DriverSummary> resolveDriver({String? plate, int? driverId}) async {
  if ((plate == null || plate.isEmpty) && driverId == null) {
    throw Exception('Provide plate or driver_id');
  }

  final qs = plate != null ? 'plate=$plate' : 'driver_id=$driverId';
  final url = Uri.parse('${AppConfig.baseUrl}/vehicles/resolve?$qs');

  final headers = <String, String>{};
  if (authToken != null) headers['Authorization'] = 'Bearer $authToken';

  final r = await http.get(url, headers: headers);

  if (r.statusCode == 200) {
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final inner = (j['vehicle_payment'] ?? j) as Map<String, dynamic>;
    return DriverSummary.fromJson(inner);
  } else {
    throw Exception(_errFromResp(r));
  }
}

/// ✅ Start Chapa payment (returns checkout URL)
Future<Map<String, dynamic>> initiateChapaPayment({
  required String plateNumber,
  required String feePlan,
  required int prepayQty,
  required DateTime coveredStart,
  required DateTime coveredEnd,
  required num amount,
}) async {
  final url = Uri.parse('${AppConfig.baseUrl}/payments/online/init');

  final payload = {
    'plate_number': plateNumber,
    'fee_plan': feePlan,
    'prepaid_qty': prepayQty,
    'covered_start_date': coveredStart.toIso8601String(),
    'covered_end_date': coveredEnd.toIso8601String(),
    'amount': amount,
    'payment_method': 'MOBILE',
  };

  final headers = {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  final r = await http.post(url, headers: headers, body: jsonEncode(payload));

  if (r.statusCode >= 200 && r.statusCode < 300) {
    final j = jsonDecode(r.body);
    return {
      'checkout_url': j['checkout_url'],
      'tx_ref': j['tx_ref'],
    };
  } else {
    throw Exception(_errFromResp(r));
  }
}

/// ✅ Verify Chapa payment status
Future<bool> verifyChapaPayment(String txRef) async {
  final url = Uri.parse('${AppConfig.baseUrl}/payments/verify/$txRef');
  final headers = {
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  final r = await http.get(url, headers: headers);

  if (r.statusCode == 200) {
    final j = jsonDecode(r.body);
    final status = j['data']?['status'] ?? j['status'];
    return status == 'success';
  } else {
    throw Exception(_errFromResp(r));
  }
}
