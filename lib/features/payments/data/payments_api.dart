import 'dart:convert';
import '../../auth/data/auth_service.dart';
import '../models/payment_models.dart';

class PxResult<T> {
  final bool success;
  final T? data;
  final String? error;
  const PxResult._(this.success, this.data, this.error);
  const PxResult.success(T data) : this._(true, data, null);
  const PxResult.error(String error) : this._(false, null, error);
}

String _errFromResp(dynamic resp) {
  try {
    final j = jsonDecode(resp.body);
    return (j['message'] ?? j['error'] ?? 'HTTP ${resp.statusCode}').toString();
  } catch (_) {
    return 'HTTP ${resp.statusCode}';
  }
}

Future<PxResult<DriverSummary>> resolveDriver({
  String? plate,
  int? driverId,
}) async {
  if ((plate == null || plate.isEmpty) && driverId == null) {
    return const PxResult.error('ታርጋ ወይም የአሽከርካሪ መለያ ያስገቡ');
  }

  final qs = plate != null ? 'plate=$plate' : 'driver_id=$driverId';
  final resp = await authGet('/vehicles/resolve?$qs');

  if (resp.statusCode == 200) {
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final inner = (j['vehicle_payment'] ?? j) as Map<String, dynamic>;
    return PxResult.success(DriverSummary.fromJson(inner));
  }

  return PxResult.error(_errFromResp(resp));
}

Future<Map<String, dynamic>> initiateChapaPayment({
  required String plateNumber,
  required String feePlan,
  required int prepayQty,
  required DateTime coveredStart,
  required DateTime coveredEnd,
  required num amount,
}) async {
  final body = {
    'plate_number': plateNumber,
    'fee_plan': feePlan,
    'prepaid_qty': prepayQty,
    'covered_start_date': coveredStart.toIso8601String(),
    'covered_end_date': coveredEnd.toIso8601String(),
    'amount': amount,
    'payment_method': 'MOBILE',
  };

  final resp = await authPost('/payments/online/init', body);

  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    final j = jsonDecode(resp.body);
    return {'checkout_url': j['checkout_url'], 'tx_ref': j['tx_ref']};
  }

  throw Exception(_errFromResp(resp));
}

Future<bool> verifyChapaPayment(String txRef) async {
  final resp = await authGet('/payments/verify/$txRef');

  if (resp.statusCode == 200) {
    final j = jsonDecode(resp.body);
    final status = j['data']?['status'] ?? j['status'];
    return status == 'success';
  }

  throw Exception(_errFromResp(resp));
}
