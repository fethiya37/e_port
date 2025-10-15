
class RouteInfo {
  final int id;
  final String departure;
  final String arrival;

  const RouteInfo({
    required this.id,
    required this.departure,
    required this.arrival,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
        id: j['id'] as int,
        departure: j['departure'] as String,
        arrival: j['arrival'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'departure': departure,
        'arrival': arrival,
      };
}

/// ─────────────────────────────────────────────
/// 🔹 RouteAssignmentItem
/// ─────────────────────────────────────────────
class RouteAssignmentItem {
  final String status; // Approved | Pending
  final DateTime startDate;
  final DateTime endDate;
  final RouteInfo route;

  const RouteAssignmentItem({
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

  Map<String, dynamic> toJson() => {
        'status': status,
        'start_date_gc': startDate.toIso8601String(),
        'end_date_gc': endDate.toIso8601String(),
        'route': route.toJson(),
      };
}

class VisibleCoverage {
  final String? associationName;
  final String? plateNumber;
  final String? driverName;
  final String? driverActiveUntil; // ISO string (yyyy-MM-dd)
  final List<RouteAssignmentItem> assignments;
  final bool notFullFilled;

  const VisibleCoverage({
    required this.associationName,
    required this.plateNumber,
    required this.driverName,
    required this.driverActiveUntil,
    required this.assignments,
    required this.notFullFilled,
  });

  factory VisibleCoverage.fromJson(Map<String, dynamic> j) => VisibleCoverage(
        associationName: j['association_name'] as String?,
        plateNumber: j['plate_number'] as String?,
        driverName: j['driver_name'] as String?,
        driverActiveUntil: j['driver_active_until'] as String?,
        assignments: (j['assignments'] as List<dynamic>? ?? [])
            .map((x) => RouteAssignmentItem.fromJson(x as Map<String, dynamic>))
            .toList(),
        notFullFilled: j['not_full_filled'] == true,
      );

  Map<String, dynamic> toJson() => {
        'association_name': associationName,
        'plate_number': plateNumber,
        'driver_name': driverName,
        'driver_active_until': driverActiveUntil,
        'assignments': assignments.map((e) => e.toJson()).toList(),
        'not_full_filled': notFullFilled,
      };
}


class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  const ApiResult.success(this.data)
      : success = true,
        error = null;

  const ApiResult.error(this.error)
      : success = false,
        data = null;
}
