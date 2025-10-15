class AuthUser {
  final int id;
  final String phoneNumber;
  final String userType; // 'Driver' | 'Controller' | ...
  final int? associationId;
  final String? associationName;
  final int? driverId;
  final String? name;

  const AuthUser({
    required this.id,
    required this.phoneNumber,
    required this.userType,
    this.associationId,
    this.associationName,
    this.driverId,
    this.name,
  });

  /// Create AuthUser from backend JSON response
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        phoneNumber: j['phone_number'] as String,
        userType: j['user_type'] as String,
        associationId: j['association_id'] as int?,
        associationName: j['association_name'] as String?,
        driverId: j['driver_id'] as int?,
        name: j['name'] as String?,
      );

  /// Convert AuthUser to JSON (for local storage)
  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'user_type': userType,
        'association_id': associationId,
        'association_name': associationName,
        'driver_id': driverId,
        'name': name,
      };
}
