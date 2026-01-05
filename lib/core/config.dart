import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  static String get baseUrl {
    // 1) --dart-define override (always wins)
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return _stripTrailingSlash(fromEnv);

    // 2) Web
    if (kIsWeb) {
      final host = Uri.base.host;
      final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
      final resolvedHost =
          (host.isEmpty || host == 'localhost') ? 'localhost' : host;
      return '$scheme://$resolvedHost:3000/api';
    }

    // 3) Android / iOS physical devices
    if (_isAndroid || _isIOS) {
      // 🟢 Your real PC LAN IP here (with /api)
      return 'http://10.193.156.7:3000/api';
    }

    // 4) Desktop dev (with /api)
    if (_isDesktop) return 'http://localhost:3000/api';

    // 5) Public fallback (already has /api)
    return 'https://eportapi.eportapp.com/api';
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
