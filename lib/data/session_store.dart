import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the login session.
///
/// The JWT lives in secure storage (Android Keystore-backed encrypted
/// prefs / iOS Keychain), not plain SharedPreferences, so it can't be
/// read off a rooted or backed-up device. Older installs kept it in
/// SharedPreferences; the first read moves it across and deletes the
/// plain copy, so users stay logged in through the update.
abstract final class SessionStore {
  static const _kToken = 'jwt_token';
  static const _kMobile = 'user_mobile'; // not secret — stays in prefs

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Cached after the first read: the token is attached to every API
  // request, and secure-storage reads cross a platform channel.
  static String? _cachedToken;
  static bool _loaded = false;

  static Future<void> saveSession({required String token, String? mobile}) async {
    await _secure.write(key: _kToken, value: token);
    _cachedToken = token;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken); // never keep a plain copy
    if (mobile != null) await p.setString(_kMobile, mobile);
  }

  static Future<String?> getToken() async {
    if (_loaded) return _cachedToken;
    String? token;
    try {
      token = await _secure.read(key: _kToken);
    } catch (e) {
      // Happens when Android restores app data from a backup onto a new
      // device: the encrypted value comes back but its Keystore key
      // doesn't. Wipe it — the user just logs in again.
      debugPrint('[session] secure read failed, clearing: $e');
      await _secure.deleteAll().catchError((_) {});
      token = null;
    }

    // One-time move from the old plain SharedPreferences location.
    final p = await SharedPreferences.getInstance();
    final legacy = p.getString(_kToken);
    if (legacy != null) {
      var migrated = true;
      if ((token == null || token.isEmpty) && legacy.isNotEmpty) {
        try {
          await _secure.write(key: _kToken, value: legacy);
          token = legacy;
        } catch (e) {
          // Keep the plain copy so the user isn't logged out; retry next launch.
          debugPrint('[session] could not migrate token to secure storage: $e');
          token = legacy;
          migrated = false;
        }
      }
      if (migrated) await p.remove(_kToken);
    }

    _cachedToken = token;
    _loaded = true;
    return token;
  }

  static Future<String?> getMobile() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kMobile);
  }

  static Future<void> clear() async {
    _cachedToken = null;
    _loaded = true;
    try {
      await _secure.delete(key: _kToken);
    } catch (e) {
      debugPrint('[session] secure delete failed: $e');
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kMobile);
  }
}
