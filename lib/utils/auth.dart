// lib/utils/auth.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config.dart';

/// What comes back from Nest /auth/login in your service
/// {
///   access_token: string,
///   user: { id, phone_number, user_type, association_id, name? },
///   exp: number, jti: string
/// }

class AuthUser {
  final int id;
  final String phoneNumber;
  final String userType; // 'Driver' | 'Owner' | 'Controller' | ...
  final int? associationId;
  final String? name;

  const AuthUser({
    required this.id,
    required this.phoneNumber,
    required this.userType,
    this.associationId,
    this.name,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        phoneNumber: j['phone_number'] as String,
        userType: j['user_type'] as String,
        associationId: j['association_id'] as int?,
        name: j['name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'user_type': userType,
        'association_id': associationId,
        'name': name,
      };
}

class LoginResult {
  final bool success;
  final AuthUser? user;
  final String? token;
  final String? error;

  const LoginResult({required this.success, this.user, this.token, this.error});
}

const _kTokenKey = 'auth_token';
const _kUserKey = 'auth_user_json';
final _sec = FlutterSecureStorage();

AuthUser? currentUser;   // in-memory cache
String? authToken;       // in-memory cache

Map<String, String> _jsonHeaders({bool withAuth = false}) => {
      'Content-Type': 'application/json',
      if (withAuth && authToken != null) 'Authorization': 'Bearer $authToken',
    };

String _extractError(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    return j['message']?.toString() ??
        j['error']?.toString() ??
        'HTTP ${r.statusCode}';
  } catch (_) {
    return 'HTTP ${r.statusCode}';
  }
}

/// Call on app start to restore session (from secure storage)
Future<void> restoreSession() async {
  try {
    final t = await _sec.read(key: _kTokenKey);
    final u = await _sec.read(key: _kUserKey);
    if (t != null && u != null) {
      authToken = t;
      currentUser = AuthUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[auth] restored user ${currentUser!.userType}');
      }
    }
  } catch (_) {
    authToken = null;
    currentUser = null;
  }
}

/// LOGIN
Future<LoginResult> login(String phone, String password) async {
  final url = Uri.parse('${AppConfig.baseUrl}/auth/login');
  final resp = await http.post(
    url,
    headers: _jsonHeaders(),
    body: jsonEncode({'phone_number': phone, 'password': password}),
  );

  if (resp.statusCode == 200) {
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = j['access_token'] as String;
    final user = AuthUser.fromJson(j['user'] as Map<String, dynamic>);

    // persist
    await _sec.write(key: _kTokenKey, value: token);
    await _sec.write(key: _kUserKey, value: jsonEncode(user.toJson()));
    // cache
    authToken = token;
    currentUser = user;

    return LoginResult(success: true, user: user, token: token);
  }

  return LoginResult(success: false, error: _extractError(resp));
}

/// LOGOUT
Future<void> logout() async {
  // best-effort server revoke
  try {
    if (authToken != null) {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/logout');
      await http.post(url, headers: _jsonHeaders(withAuth: true));
    }
  } catch (_) {
    // ignore network errors on logout
  }
  // clear client state
  await _sec.delete(key: _kTokenKey);
  await _sec.delete(key: _kUserKey);
  authToken = null;
  currentUser = null;
}

/// Helper for authorized GET/POST elsewhere in the app.
Future<http.Response> authGet(String path) {
  final url = Uri.parse('${AppConfig.baseUrl}$path');
  return http.get(url, headers: _jsonHeaders(withAuth: true));
}

Future<http.Response> authPost(String path, Map<String, dynamic> body) {
  final url = Uri.parse('${AppConfig.baseUrl}$path');
  return http.post(url, headers: _jsonHeaders(withAuth: true), body: jsonEncode(body));
}

// --- Change Password ---

class ChangePasswordResult {
  final bool success;
  final String? error;
  const ChangePasswordResult({required this.success, this.error});
}

Future<ChangePasswordResult> changePassword(String oldPassword, String newPassword) async {
  final url = Uri.parse('${AppConfig.baseUrl}/users/me/password');
  final resp = await http.patch(
    url,
    headers: _jsonHeaders(withAuth: true),
    body: jsonEncode({
      'old_password': oldPassword,
      'new_password': newPassword,
    }),
  );

  if (resp.statusCode == 200) {
    return const ChangePasswordResult(success: true);
  }
  return ChangePasswordResult(success: false, error: _extractError(resp));
}
