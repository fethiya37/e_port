
class DriverPolicy {
  final num planFee; 
  final num dailyFinePercent;

  const DriverPolicy({
    required this.planFee,
    required this.dailyFinePercent,
  });

  factory DriverPolicy.fromJson(Map<String, dynamic> j) => DriverPolicy(
        planFee: (j['plan_fee'] ?? j['planFee'] ?? 0) as num,
        dailyFinePercent:
            (j['daily_fine_percent'] ?? j['dailyFinePercent'] ?? 0) as num,
      );

  Map<String, dynamic> toJson() => {
        'plan_fee': planFee,
        'daily_fine_percent': dailyFinePercent,
      };
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

  Map<String, dynamic> toJson() => {
        'association_name': associationName,
        'driver_name': driverName,
        'plate_number': plateNumber,
        'is_weekly': isWeekly,
        'active_until_date': activeUntilDate,
        'interest_accrued': interestAccrued,
        'policy': policy.toJson(),
      };
}


class ApplyPaymentResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? body;

  const ApplyPaymentResult({
    required this.success,
    this.error,
    this.body,
  });

  factory ApplyPaymentResult.success(Map<String, dynamic>? body) =>
      ApplyPaymentResult(success: true, body: body);

  factory ApplyPaymentResult.error(String message) =>
      ApplyPaymentResult(success: false, error: message);
}
