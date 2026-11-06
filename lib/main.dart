import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'data/pending_order_store.dart';
import 'data/push_service.dart';
import 'data/session_store.dart';
import 'presentation/auth/biometric_lock_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/shell/main_shell.dart';
import 'presentation/widgets/qr_loader.dart';
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
  // Soft-update signal: there's a newer version on Play Store but the
  // client is still within the supported window. MainShell/HomeTab turn
  // this into a dismissible banner on the home surface.
  bool _updateAvailable = false;
  String _updateMessage = '';
  String _playStoreUrl = '';
  String _latestVersion = '';

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

    // Fire version-check, token read, biometric pref read, and (if
    // we had a token on disk) session validation IN PARALLEL. Previously
    // these were sequential and the boot screen could sit for 11+ seconds
    // on a bad network because each timeout waited on the previous one.
    final versionFuture = ApiClient.instance
        .get('/api/app/version-check?version=$appVersion', auth: false)
        .timeout(const Duration(seconds: 3))
        .catchError((Object e) {
      debugPrint('Startup version check failed/skipped: $e');
      return null;
    });

    final token = await SessionStore.getToken();
    final hasToken = token != null && token.isNotEmpty;

    final prefsFuture = SharedPreferences.getInstance()
        .then((p) => p.getBool('fingerprint_login_enabled') ?? false)
        .catchError((Object e) {
      debugPrint('Could not read biometric pref: $e');
      return false;
    });

    Future<bool> validateFuture;
    if (hasToken) {
      validateFuture = ApiClient.instance
          .get('/auth/me')
          .timeout(const Duration(seconds: 3))
          .then((_) => true)
          .catchError((Object e) {
        if (e is ApiException) {
          debugPrint('Session validation failed: ${e.message}');
          return false; // 401 → force login
        }
        // Network error — keep the cached session so offline users can
        // still open the app.
        debugPrint('Session validation skipped (network): $e');
        return true;
      });
    } else {
      validateFuture = Future.value(false);
    }

    final results = await Future.wait<Object?>([
      versionFuture,
      validateFuture,
      prefsFuture,
    ]);

    final versionRes = results[0];
    final loggedIn = results[1] as bool;
    final biometricEnabled = results[2] as bool;

    if (versionRes is Map && versionRes['forceUpdate'] == true) {
      if (mounted) {
        setState(() {
          _updateRequired = true;
          _updateMessage = versionRes['updateMessage']?.toString() ??
              'Please update app to continue';
          _playStoreUrl = versionRes['playStoreUrl']?.toString() ?? '';
          _loading = false;
        });
      }
      return;
    }

    // Soft update: there's a newer version but we're still supported. Hold
    // the signal so MainShell can show a dismissible banner on home.
    final Map? versionMap = versionRes is Map ? versionRes : null;
    final updateAvailable = versionMap?['updateAvailable'] == true;

    final needsBiometric = loggedIn && biometricEnabled;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _loggedIn = loggedIn;
      _biometricLocked = needsBiometric;
      _updateAvailable = updateAvailable;
      if (updateAvailable && versionMap != null) {
        _updateMessage = versionMap['updateMessage']?.toString() ??
            'A new version is available.';
        _playStoreUrl = versionMap['playStoreUrl']?.toString() ?? '';
        _latestVersion = versionMap['latestVersion']?.toString() ?? '';
      }
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
              body: QrBootLoader(status: 'Securing your privacy'),
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
                      updateAvailable: _updateAvailable,
                      updateLatestVersion: _latestVersion,
                      updateMessage: _updateMessage,
                      updatePlayStoreUrl: _playStoreUrl,
                    ),
    );
  }
}
