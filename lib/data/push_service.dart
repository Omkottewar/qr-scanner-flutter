import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'session_store.dart';

// FCM lifecycle for QR 4 Emergency:
//
// 1. Firebase.initializeApp() is called once at cold start (main.dart) so
//    the plugin can wire up the background isolate handler.
// 2. On login (or app resume with a valid session) we call
//    PushService.instance.registerForCurrentSession() which:
//      • requests notification permission (Android 13+ / iOS)
//      • pulls the FCM token
//      • POSTs it to /profile/device-token so the backend can push to us
//      • subscribes to onTokenRefresh and re-POSTs on rotation
// 3. Incoming messages:
//      • Foreground → onMessage → show a local notification manually,
//        since FCM won't display banners while the app is on-screen.
//      • Background/terminated → OS shows the notification automatically
//        from the "notification" payload; our handler only runs for
//        data-only pushes (we don't send those yet, but the hook is here).
//
// Failures are logged and swallowed. A broken push pipeline must never
// keep the user from using the rest of the app.

const String _kAndroidChannelId = 'qr_events';
const String _kAndroidChannelName = 'QR events';
const String _kAndroidChannelDesc =
    'Scans, calls, and other events on your QR.';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Runs in a separate isolate for data-only pushes when the app is
  // terminated. Firebase.initializeApp() must be safe to call here —
  // firebase_core handles the "already initialized" case.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[push:bg] ${message.messageId} data=${message.data}');
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _bootstrapped = false;
  bool _registeredForSession = false;
  StreamSubscription<String>? _tokenRefreshSub;

  // One-time cold-start setup. Safe to call multiple times.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase.initializeApp failed: $e');
      // If Firebase configuration files are missing, we bail — the rest
      // of the app should still work.
      return;
    }
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    await _initLocalNotifications();
    // Foreground: we render our own banner via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    // Tap on a notification while backgrounded → app resumed.
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  Future<void> _initLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    // Ensure the Android channel exists before any notify() call — Android
    // 8+ silently drops posts to a nonexistent channel.
    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kAndroidChannelId,
        _kAndroidChannelName,
        description: _kAndroidChannelDesc,
        importance: Importance.high,
      ),
    );
  }

  // Called after login / on app-resume when we have a valid session.
  // Idempotent — safe to call on every launch.
  Future<void> registerForCurrentSession() async {
    if (_registeredForSession) return;
    try {
      final token = await SessionStore.getToken();
      if (token == null || token.isEmpty) return;
      await bootstrap();

      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] user denied notification permission');
        return;
      }

      // iOS may not return an APNs token immediately after install; the
      // FCM token depends on it. Do a short retry so we don't ship a null.
      String? fcmToken;
      for (var i = 0; i < 3; i++) {
        fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('[push] getToken returned null — will retry on refresh');
      } else {
        await _postDeviceToken(fcmToken);
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen(_postDeviceToken);
      _registeredForSession = true;
    } catch (e) {
      debugPrint('[push] registerForCurrentSession failed: $e');
    }
  }

  // Wipe token registration on logout so we don't keep pushing to a device
  // whose user just signed out. Best-effort — a delete-token failure won't
  // block the logout flow.
  Future<void> unregister() async {
    _registeredForSession = false;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[push] deleteToken failed: $e');
    }
  }

  Future<void> _postDeviceToken(String token) async {
    try {
      debugPrint('[push] posting device token (…${token.substring(token.length - 8)})');
      await ApiClient.instance
          .post('/profile/device-token', {'deviceToken': token});
    } catch (e) {
      debugPrint('[push] device-token POST failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] as String? ?? 'QR 4 Emergency';
    final body = n?.body ?? message.data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _kAndroidChannelId,
          _kAndroidChannelName,
          channelDescription: _kAndroidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    // Placeholder for deep-linking. Route on message.data['type']:
    //   qr_scanned / qr_call_incoming / qr_call_missed / qr_call_completed.
    // Left as a TODO — wire when the routes are ready.
    debugPrint('[push] opened via notification: ${message.data}');
  }

  // Utility used only when the caller wants to force a re-registration,
  // e.g., after a settings toggle. Rarely needed in the normal flow.
  Future<void> forceRefresh() async {
    _registeredForSession = false;
    await registerForCurrentSession();
  }

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
