import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return _stripTrailingSlash(fromEnv);

    if (kIsWeb) {
      final host = Uri.base.host;
      final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
      final resolvedHost = (host.isEmpty || host == 'localhost')
          ? 'localhost'
          : host;
      return '$scheme://$resolvedHost:3000/api';
    }

    if (_isAndroid || _isIOS) {
      return 'https://eportapi.eportline.com/api';
    }

    if (_isDesktop) return 'http://localhost:4000/api';

    return 'https://eportapi.eportline.com/api';
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
