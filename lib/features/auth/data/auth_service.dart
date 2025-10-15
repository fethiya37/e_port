import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config.dart'; // ✅ for AppConfig
import '../../../core/routes.dart'; // ✅ for navigatorKey
import '../models/auth_user.dart'; // ✅ AuthUser model

/// Represents the result of a login attempt
class LoginResult {
  final bool success;
  final AuthUser? user;
  final String? token;
  final String? error;
  const LoginResult({required this.success, this.user, this.token, this.error});
}

// ───────────────────────────────────────────────
// 🔒 Secure Storage Keys
// ───────────────────────────────────────────────
const _kTokenKey = 'auth_token';
const _kUserKey = 'auth_user_json';
final _sec = FlutterSecureStorage();

AuthUser? currentUser; // cached logged-in user
String? authToken; // cached token
Timer? _expiryTimer;

// only allow these user types in the app
const Set<String> _allowedUserTypes = {'Driver', 'Controller'};

// ───────────────────────────────────────────────
// 🧱 Helper Functions
// ───────────────────────────────────────────────

Map<String, String> _jsonHeaders({bool withAuth = false}) => {
      'Content-Type': 'application/json',
      if (withAuth && authToken != null) 'Authorization': 'Bearer $authToken',
    };

String _extractError(http.Response r) {
  try {
    final j = jsonDecode(r.body);
    return j['message']?.toString() ?? j['error']?.toString() ?? 'HTTP ${r.statusCode}';
  } catch (_) {
    return 'HTTP ${r.statusCode}';
  }
}

Future<void> _clearLocalSession() async {
  await _sec.delete(key: _kTokenKey);
  await _sec.delete(key: _kUserKey);
  authToken = null;
  currentUser = null;
  _expiryTimer?.cancel();
}

/// 🔥 Handle unauthorized / expired token safely (no BuildContext misuse)
Future<void> _handleUnauthorized() async {
  debugPrint('[auth] Token expired or unauthorized — logging out');
  await _clearLocalSession();

  // Redirect immediately to login page (no context needed)
  navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);

  // Show snack safely after current frame to avoid async context issues
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  });
}

/// Automatically logout when token expiry is reached
void _startTokenExpiryWatcher(int expUnix) {
  _expiryTimer?.cancel();
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final secondsUntilExp = expUnix - nowSec;
  if (secondsUntilExp > 0) {
    _expiryTimer = Timer(Duration(seconds: secondsUntilExp - 5), _handleUnauthorized);
    debugPrint('[auth] Token expiry watcher started ($secondsUntilExp s)');
  }
}

// ───────────────────────────────────────────────
// 🔁 Session Management
// ───────────────────────────────────────────────

/// Restore session on app start
Future<void> restoreSession() async {
  try {
    final t = await _sec.read(key: _kTokenKey);
    final u = await _sec.read(key: _kUserKey);
    if (t != null && u != null) {
      final parsedUser = AuthUser.fromJson(jsonDecode(u));
      if (!_allowedUserTypes.contains(parsedUser.userType)) {
        debugPrint('[auth] blocked restore for ${parsedUser.userType}');
        await _clearLocalSession();
        return;
      }
      authToken = t;
      currentUser = parsedUser;
      debugPrint('[auth] restored user ${currentUser!.userType}');
    }
  } catch (_) {
    await _clearLocalSession();
  }
}

// ───────────────────────────────────────────────
// 🔑 Login / Logout
// ───────────────────────────────────────────────

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
    final user = AuthUser.fromJson(j['user']);

    if (!_allowedUserTypes.contains(user.userType)) {
      return const LoginResult(
        success: false,
        error: 'Your account type is not permitted on this app',
      );
    }

    await _sec.write(key: _kTokenKey, value: token);
    await _sec.write(key: _kUserKey, value: jsonEncode(user.toJson()));

    authToken = token;
    currentUser = user;

    if (j['exp'] != null) _startTokenExpiryWatcher(j['exp']);

    return LoginResult(success: true, user: user, token: token);
  }

  return LoginResult(success: false, error: _extractError(resp));
}

/// LOGOUT
Future<void> logout() async {
  try {
    if (authToken != null) {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/logout');
      await http.post(url, headers: _jsonHeaders(withAuth: true));
    }
  } catch (_) {}
  await _clearLocalSession();
}

// ───────────────────────────────────────────────
// 🌐 Authorized API Helpers
// ───────────────────────────────────────────────

Future<http.Response> authGet(String path) async {
  final url = Uri.parse('${AppConfig.baseUrl}$path');
  final resp = await http.get(url, headers: _jsonHeaders(withAuth: true));
  if (resp.statusCode == 401 || resp.statusCode == 403) await _handleUnauthorized();
  return resp;
}

Future<http.Response> authPost(String path, Map<String, dynamic> body) async {
  final url = Uri.parse('${AppConfig.baseUrl}$path');
  final resp = await http.post(
    url,
    headers: _jsonHeaders(withAuth: true),
    body: jsonEncode(body),
  );
  if (resp.statusCode == 401 || resp.statusCode == 403) await _handleUnauthorized();
  return resp;
}

// ───────────────────────────────────────────────
// 🔐 Change Password
// ───────────────────────────────────────────────

class ChangePasswordResult {
  final bool success;
  final String? error;
  const ChangePasswordResult({required this.success, this.error});
}

Future<ChangePasswordResult> changePassword(
  String oldPassword,
  String newPassword,
) async {
  final url = Uri.parse('${AppConfig.baseUrl}/users/me/password');
  final resp = await http.patch(
    url,
    headers: _jsonHeaders(withAuth: true),
    body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
  );

  if (resp.statusCode == 200) return const ChangePasswordResult(success: true);
  if (resp.statusCode == 401 || resp.statusCode == 403) await _handleUnauthorized();
  return ChangePasswordResult(success: false, error: _extractError(resp));
}
