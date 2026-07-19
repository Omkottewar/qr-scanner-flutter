import 'package:shared_preferences/shared_preferences.dart';

abstract final class SessionStore {
  static const _kToken = 'jwt_token';
  static const _kMobile = 'user_mobile';

  static Future<void> saveSession({required String token, String? mobile}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (mobile != null) await p.setString(_kMobile, mobile);
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  static Future<String?> getMobile() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kMobile);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kMobile);
  }
}
