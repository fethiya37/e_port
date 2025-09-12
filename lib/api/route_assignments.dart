// lib/api/route_assignments.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../utils/auth.dart'; // uses authGet helper & bearer token

class RouteInfo {
  final int id;
  final String? group;
  final String departure;
  final String arrival;
  RouteInfo({required this.id, this.group, required this.departure, required this.arrival});

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
    id: j['id'] as int,
    group: j['group'] as String?,
    departure: j['departure'] as String,
    arrival: j['arrival'] as String,
  );
}

class RouteAssignmentItem {
  final int id;
  final String status; // 'Pending' | 'Approved'
  final DateTime startDate; // GC
  final DateTime endDate;   // GC
  final bool isWeekly;
  final String? vehiclePlate;
  final RouteInfo route;

  RouteAssignmentItem({
    required this.id,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.isWeekly,
    required this.vehiclePlate,
    required this.route,
  });

  factory RouteAssignmentItem.fromJson(Map<String, dynamic> j) => RouteAssignmentItem(
    id: j['id'] as int,
    status: j['status'] as String,
    startDate: DateTime.parse(j['start_date'] as String),
    endDate: DateTime.parse(j['end_date'] as String),
    isWeekly: j['is_weekly'] as bool,
    vehiclePlate: j['vehicle_plate'] as String?,
    route: RouteInfo.fromJson(j['route'] as Map<String, dynamic>),
  );
}

class VisibleCoverage {
  final int driverId;
  final bool coverageActive;
  final DateTime? windowFrom; // GC
  final DateTime? windowTo;   // GC
  final bool? isWeekly;
  final List<RouteAssignmentItem> assignments;

  VisibleCoverage({
    required this.driverId,
    required this.coverageActive,
    required this.windowFrom,
    required this.windowTo,
    required this.isWeekly,
    required this.assignments,
  });

  factory VisibleCoverage.fromJson(Map<String, dynamic> j) => VisibleCoverage(
    driverId: j['driver_id'] as int,
    coverageActive: j['coverage_active'] as bool,
    windowFrom: j['window']?['from'] != null ? DateTime.parse(j['window']['from'] as String) : null,
    windowTo: j['window']?['to']   != null ? DateTime.parse(j['window']['to']   as String) : null,
    isWeekly: j['window']?['is_weekly'] as bool?,
    assignments: (j['assignments'] as List<dynamic>).map((x) => RouteAssignmentItem.fromJson(x as Map<String, dynamic>)).toList(),
  );
}

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;
  ApiResult.success(this.data) : success = true, error = null;
  ApiResult.error(this.error)  : success = false, data = null;
}

Future<ApiResult<VisibleCoverage>> fetchVisibleCoverage({String? plateNumber, int? driverId}) async {
  if (plateNumber == null && driverId == null) {
    return ApiResult.error('plateNumber or driverId is required');
  }
  final qp = <String, String>{};
  if (plateNumber != null) qp['plate_number'] = plateNumber;
  if (driverId != null) qp['driver_id'] = '$driverId';

  final uri = Uri.parse('${AppConfig.baseUrl}/route-assignments/visible-coverage').replace(queryParameters: qp);

  try {
    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    });
    if (resp.statusCode == 200) {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return ApiResult.success(VisibleCoverage.fromJson(j));
    }
    final j = jsonDecode(resp.body);
    return ApiResult.error(j['message']?.toString() ?? 'HTTP ${resp.statusCode}');
  } catch (_) {
    return ApiResult.error('Network error');
  }
}
