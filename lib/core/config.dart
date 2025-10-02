import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Central place for your backend base URL.
/// Priority:
/// 1) --dart-define=API_BASE_URL=... (recommended)
/// 2) If Web: use current origin (protocol + host) + :3000 fallback
/// 3) If Android emulator: 10.0.2.2:3000
/// 4) If iOS simulator / Desktop: localhost:3000
/// 5) Final fallback: your public server IP:3000
class AppConfig {
  static String get baseUrl {
    // 1) CI / run-time override
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return _stripTrailingSlash(fromEnv);

    // 2) Web
    if (kIsWeb) {
      final host = Uri.base.host;
      final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
      final resolvedHost = (host.isEmpty || host == 'localhost')
          ? 'localhost'
          : host;
      return '$scheme://$resolvedHost:3000';
    }

    // 3) Android emulator
    // 3) Android (real device vs emulator)
    if (_isAndroid) {
      // If running inside Android emulator → use 10.0.2.2
      // If running on a real device (adb reverse in use) → use localhost
      final isEmulator = !Platform.environment.containsKey('ANDROID_BOOTLOGO');
      // crude check, or you can use `device_info_plus` package for accuracy
      return isEmulator ? 'http://10.0.2.2:3000' : 'http://localhost:3000/api';
    }

    // 4) iOS simulator / Desktop
    if (_isIOS || _isDesktop) return 'http://localhost:3000';

    // 5) Public server fallback
    return 'http://72.60.90.233:3000';
  }

  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static bool get _isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static bool get _isDesktop {
    try {
      return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  static String _stripTrailingSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
