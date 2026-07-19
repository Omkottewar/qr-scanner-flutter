import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'data/pending_order_store.dart';
import 'data/push_service.dart';
import 'data/session_store.dart';
import 'presentation/auth/biometric_lock_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/shell/main_shell.dart';
import 'presentation/widgets/update_required_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget: initializes Firebase + local-notifications plumbing.
  // Errors are logged and swallowed by PushService itself so a missing
  // google-services.json never blocks the app from booting.
  PushService.instance.bootstrap();
  runApp(const EmergencyAlertApp());
}

class EmergencyAlertApp extends StatefulWidget {
  const EmergencyAlertApp({super.key});

  @override
  State<EmergencyAlertApp> createState() => _EmergencyAlertAppState();
}

class _EmergencyAlertAppState extends State<EmergencyAlertApp> {
  bool _loading = true;
  bool _loggedIn = false;
  bool _biometricLocked = false;
  bool _updateRequired = false;
  String _updateMessage = '';
  String _playStoreUrl = '';

  @override
  void initState() {
    super.initState();
    sessionExpiredSignal.addListener(_onSessionExpired);
    _boot();
  }

  @override
  void dispose() {
    sessionExpiredSignal.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _onSessionExpired() {
    if (!mounted) return;
    if (_loggedIn) {
      setState(() => _loggedIn = false);
    }
  }

  Future<void> _boot() async {
    const appVersion = '1.0.5'; // Current mobile app version
    try {
      // Execute version check on startup
      final res = await ApiClient.instance
          .get('/api/app/version-check?version=$appVersion', auth: false)
          .timeout(const Duration(seconds: 5));
      if (res is Map && res['forceUpdate'] == true) {
        if (mounted) {
          setState(() {
            _updateRequired = true;
            _updateMessage = res['updateMessage']?.toString() ?? 'Please update app to continue';
            _playStoreUrl = res['playStoreUrl']?.toString() ?? '';
            _loading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Startup version check failed/skipped: $e');
    }

    final t = await SessionStore.getToken();
    bool loggedIn = t != null && t.isNotEmpty;

    // Validate the token with the server. If it's expired or revoked the
    // 401-handler in ApiClient already cleared the session; we just need to
    // catch the resulting ApiException so the user lands on login cleanly.
    if (loggedIn) {
      try {
        await ApiClient.instance
            .get('/auth/me')
            .timeout(const Duration(seconds: 6));
      } on ApiException catch (e) {
        debugPrint('Session validation failed: ${e.message}');
        loggedIn = false;
      } catch (e) {
        // Network error — let the user reach the app with cached session
        // rather than forcing them to login when offline.
        debugPrint('Session validation skipped (network): $e');
      }
    }

    // Whether the session needs a biometric unlock before reaching the app.
    // The actual prompt happens in BiometricLockScreen — keeping it out of
    // _boot() lets the user retry/escape without re-running the whole boot.
    bool needsBiometric = false;
    if (loggedIn) {
      try {
        final prefs = await SharedPreferences.getInstance();
        needsBiometric = prefs.getBool('fingerprint_login_enabled') ?? false;
      } catch (e) {
        debugPrint('Could not read biometric pref: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _loggedIn = loggedIn;
      _biometricLocked = needsBiometric;
    });

    // Register for push once we're confident the session is valid. The
    // service itself is a no-op when the token is missing, so calling
    // this on every boot (including logged-out) is cheap.
    if (loggedIn) {
      PushService.instance.registerForCurrentSession();
      // Pending-order reconciliation. If the app was killed mid-checkout
      // there's a persisted orderId on disk; ask the backend what
      // happened to it so we don't accidentally double-charge on retry.
      _reconcilePendingOrder();
    }
  }

  // Best-effort: probes GET /payments/status/:orderId for any order id
  // saved to disk before an OS kill. Verified → clear the marker and
  // show a "you're already paid" toast on the next frame. Failed →
  // clear it. Created (still pending on Razorpay) → leave the marker
  // so the user's next tap can resume.
  Future<void> _reconcilePendingOrder() async {
    try {
      final pending = await PendingOrderStore.read();
      if (pending == null) return;
      debugPrint('[boot] pending order found: ${pending.orderId} (${pending.purpose})');
      final res = await ApiClient.instance
          .get('/payments/status/${pending.orderId}')
          .timeout(const Duration(seconds: 8));
      if (res is! Map || res['found'] != true) {
        // No record on the backend — safe to drop.
        await PendingOrderStore.clear();
        return;
      }
      final status = res['status']?.toString();
      if (status == 'verified' || status == 'failed') {
        await PendingOrderStore.clear();
        if (mounted && status == 'verified') {
          // Best-effort toast so the user knows an earlier attempt
          // did complete. History tab refresh will show the QR.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _scaffoldContext;
            if (ctx == null) return;
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('A previous payment completed. Your QR is active.'),
              ),
            );
          });
        }
      }
      // Otherwise still 'created' — leave the marker in place; a stale
      // one gets auto-cleared by PendingOrderStore.read() after 24h.
    } catch (e) {
      debugPrint('[boot] reconcilePendingOrder skipped: $e');
    }
  }

  // Captured for the reconciliation SnackBar. The MainShell context
  // is the closest ScaffoldMessenger ancestor; grabbed via the root
  // navigator when needed. Null-safe — if the shell isn't up yet the
  // toast is silently dropped.
  BuildContext? get _scaffoldContext =>
      _navKey.currentContext;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  Future<void> _signOutFromLock() async {
    await SessionStore.clear();
    await PushService.instance.unregister();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _biometricLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_updateRequired) {
      return MaterialApp(
        title: 'Emergency Alert',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: UpdateRequiredScreen(
          message: _updateMessage,
          playStoreUrl: _playStoreUrl,
        ),
      );
    }

    return MaterialApp(
      title: 'Emergency Alert',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: _loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          : !_loggedIn
              ? LoginScreen(
                  key: const ValueKey('login'),
                  onLoggedIn: () {
                    PushService.instance.registerForCurrentSession();
                    setState(() {
                      _loggedIn = true;
                      _biometricLocked = false;
                    });
                  },
                )
              : _biometricLocked
                  ? BiometricLockScreen(
                      key: const ValueKey('biometric-lock'),
                      onUnlocked: () =>
                          setState(() => _biometricLocked = false),
                      onSignOut: _signOutFromLock,
                    )
                  : MainShell(
                      key: const ValueKey('shell'),
                      onLogout: () {
                        PushService.instance.unregister();
                        setState(() => _loggedIn = false);
                      },
                    ),
    );
  }
}
