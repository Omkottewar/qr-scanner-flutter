import 'package:flutter/foundation.dart';

/// Backend base URL. Override at build time:
/// `flutter run --dart-define=API_BASE=http://192.168.1.5:3000`
///
/// Uses [kIsWeb] / [defaultTargetPlatform] instead of `dart:io` [Platform]
/// so the app runs on **Web**, mobile, and desktop.
class AppConfig {
  static String get apiBase {
    const fromEnv = String.fromEnvironment('API_BASE');
    if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
    if (kIsWeb) {
      // Flutter Web cannot use dart:io Platform; default API on same machine.
      return 'https://pi-backend-qkjh.onrender.com';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator: host loopback
      return 'https://pi-backend-qkjh.onrender.com';
    }
    return 'https://pi-backend-qkjh.onrender.com';
  }
}
