import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import '../../auth/data/auth_service.dart'; // for authToken
import '../models/route_assignment_models.dart'; // ✅ import models

/// Fetch visible coverage **by plate number**
Future<ApiResult<VisibleCoverage>> fetchVisibleCoverageByPlate({
  required String plateNumber,
}) async {
  final uri = Uri.parse(
    '${AppConfig.baseUrl}/route-assignments/visible-coverage',
  ).replace(queryParameters: {'plate_number': plateNumber});

  try {
    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    });

    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode == 200) {
      return ApiResult.success(VisibleCoverage.fromJson(j));
    }

    return ApiResult.error(
      j['message']?.toString() ?? 'HTTP ${resp.statusCode}',
    );
  } catch (_) {
    return ApiResult.error('የኔትዎርክ ችግር። እባክዎ ደግመው ይሞክሩ።');
  }
}

/// Fetch visible coverage **by driverId**
Future<ApiResult<VisibleCoverage>> fetchVisibleCoverageByDriverId({
  required int driverId,
}) async {
  final uri = Uri.parse(
    '${AppConfig.baseUrl}/route-assignments/visible-coverage',
  ).replace(queryParameters: {'driver_id': driverId.toString()});

  try {
    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    });

    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    if (resp.statusCode == 200) {
      return ApiResult.success(VisibleCoverage.fromJson(j));
    }

    return ApiResult.error(
      j['message']?.toString() ?? 'HTTP ${resp.statusCode}',
    );
  } catch (_) {
    return ApiResult.error('የኔትዎርክ ችግር። እባክዎ ደግመው ይሞክሩ።');
  }
}
