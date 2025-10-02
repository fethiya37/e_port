import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../utils/auth.dart'; // bearer token handling

class RouteInfo {
  final int id;
  final String departure;
  final String arrival;

  RouteInfo({
    required this.id,
    required this.departure,
    required this.arrival,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
        id: j['id'] as int,
        departure: j['departure'] as String,
        arrival: j['arrival'] as String,
      );
}

class RouteAssignmentItem {
  final String status; // Approved | Pending
  final DateTime startDate;
  final DateTime endDate;
  final RouteInfo route;

  RouteAssignmentItem({
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.route,
  });

  factory RouteAssignmentItem.fromJson(Map<String, dynamic> j) =>
      RouteAssignmentItem(
        status: j['status'] as String,
        startDate: DateTime.parse(j['start_date_gc'] as String),
        endDate: DateTime.parse(j['end_date_gc'] as String),
        route: RouteInfo.fromJson(j['route'] as Map<String, dynamic>),
      );
}

class VisibleCoverage {
  final String? associationName;
  final String? plateNumber;
  final String? driverName;
  final String? driverActiveUntil; // ISO string (yyyy-MM-dd)
  final List<RouteAssignmentItem> assignments;

  /// 🔑 Flag when backend says coverage is not fulfilled
  final bool notFullFilled;

  VisibleCoverage({
    required this.associationName,
    required this.plateNumber,
    required this.driverName,
    required this.driverActiveUntil,
    required this.assignments,
    required this.notFullFilled,
  });

  factory VisibleCoverage.fromJson(Map<String, dynamic> j) {
    final isNotFull = j['not_full_filled'] == true;

    return VisibleCoverage(
      associationName: j['association_name'] as String?,
      plateNumber: j['plate_number'] as String?,
      driverName: j['driver_name'] as String?,
      driverActiveUntil: j['driver_active_until'] as String?,
      assignments: (j['assignments'] as List<dynamic>? ?? [])
          .map((x) => RouteAssignmentItem.fromJson(x as Map<String, dynamic>))
          .toList(),
      notFullFilled: isNotFull,
    );
  }
}

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult.success(this.data)
      : success = true,
        error = null;
  ApiResult.error(this.error)
      : success = false,
        data = null;
}

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
    return ApiResult.error('የኔትዎርክ ችግኝ። እባክዎ ደግመው ይሞክሩ።');
  }
}

/// Fetch visible coverage **by driverId** (for logged-in Driver users)
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
    return ApiResult.error('የኔትዎርክ ችግኝ። እባክዎ ደግመው ይሞክሩ።');
  }
}
