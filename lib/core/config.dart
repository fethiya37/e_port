// lib/core/config.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  static String get baseUrl {
    // Prefer a build-time override (see step 4), but fall back smartly.
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
      return '$scheme://$host:3000';
    }

    // Physical Android + ADB reverse to your PC’s 3000
    if (Platform.isAndroid) return 'http://127.0.0.1:3000';

    // iOS simulator / desktop
    return 'http://localhost:3000';
  }
}
