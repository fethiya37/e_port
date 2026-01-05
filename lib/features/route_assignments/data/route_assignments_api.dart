import 'dart:convert';
import '../../auth/data/auth_service.dart';
import '../models/route_assignment_models.dart';

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;
  const ApiResult._(this.success, this.data, this.error);
  const ApiResult.success(T data) : this._(true, data, null);
  const ApiResult.error(String error) : this._(false, null, error);
}

Future<ApiResult<VisibleCoverage>> fetchVisibleCoverageByPlate({
  required String plateNumber,
}) async {
  try {
    final resp = await authGet(
      '/route-assignments/visible-coverage?plate_number=$plateNumber',
    );

    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return ApiResult.success(VisibleCoverage.fromJson(j));
    }

    try {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return ApiResult.error(j['message']?.toString() ?? 'HTTP ${resp.statusCode}');
    } catch (_) {
      return ApiResult.error('HTTP ${resp.statusCode}');
    }
  } catch (_) {
    return const ApiResult.error('የኔትዎርክ ችግር። እባክዎ ደግመው ይሞክሩ።');
  }
}

Future<ApiResult<VisibleCoverage>> fetchVisibleCoverageByDriverId({
  required int driverId,
}) async {
  try {
    final resp = await authGet(
      '/route-assignments/visible-coverage?driver_id=$driverId',
    );

    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return ApiResult.success(VisibleCoverage.fromJson(j));
    }

    try {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return ApiResult.error(j['message']?.toString() ?? 'HTTP ${resp.statusCode}');
    } catch (_) {
      return ApiResult.error('HTTP ${resp.statusCode}');
    }
  } catch (_) {
    return const ApiResult.error('የኔትዎርክ ችግር። እባክዎ ደግመው ይሞክሩ።');
  }
}
