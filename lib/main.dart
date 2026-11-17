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
import 'presentation/widgets/cover_ad_screen.dart';
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
  // Full-page cover ad shown as the first surface a signed-in user sees
  // after authentication clears (fresh cold start with valid session,
  // post-login, or post-biometric-unlock). Logged-out users never see
  // it. Cleared once the user skips or the auto-dismiss timer fires.
  bool _showCoverAd = false;
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
    // Reset push registration so the next login posts this device's
    // token for the new session. Without this, `_registeredForSession`
    // stayed true and the next login skipped registration.
    PushService.instance.unregister();
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
        // Only a real 401 means the session is gone. ApiClient also wraps
        // network failures and 5xx errors as ApiException, so checking the
        // type alone logged out every user who opened the app offline or
        // while the server was cold-starting.
        if (e is ApiException && e.statusCode == 401) {
          debugPrint('Session validation failed: ${e.message}');
          return false;
        }
        // Network error / timeout / server error — keep the cached
        // session so offline users can still open the app.
        debugPrint('Session validation skipped: $e');
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
      // Cold start with a valid session and no biometric gate → user
      // lands straight in the shell slot, so arm the ad now. If a
      // biometric gate is pending, _onUnlocked arms it instead.
      _showCoverAd = loggedIn && !needsBiometric;
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

  // Finishes a checkout the app was killed in the middle of. The order id,
  // the QR form (for a new QR) and — once Razorpay reported success — the
  // payment id + signature are saved to disk during checkout, so here we
  // can finish the job instead of only telling the user "you're paid":
  //   • new QR, paid, no QR yet  → POST /qr/create with the saved form
  //   • renewal, paid, not applied → POST /qr/:id/renew/verify
  //   • already done             → clear the marker, tell the user
  //   • not paid / failed        → clear (or keep while still pending)
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
      final hasQr = res['qr_id'] != null;
      // `consumed` = the payment already created/renewed a QR. Older
      // servers don't send it; for them fall back to the old signals.
      final consumed = res.containsKey('consumed')
          ? res['consumed'] == true
          : (pending.purpose == 'qr_create' ? hasQr : status == 'verified');
      final paid = status == 'verified' || pending.hasPaymentProof;

      if (consumed) {
        await PendingOrderStore.clear();
        _showBootMessage(pending.purpose == 'qr_renew'
            ? 'A previous renewal payment completed. Your QR is renewed.'
            : 'A previous payment completed. Your QR is active.');
        return;
      }

      if (paid && pending.purpose == 'qr_create' && pending.createBody != null) {
        await ApiClient.instance.post('/qr/create', {
          ...pending.createBody!,
          'razorpay_order_id': pending.orderId,
          'razorpay_payment_id': pending.paymentId ?? '',
          'razorpay_signature': pending.signature ?? '',
        });
        await PendingOrderStore.clear();
        _showBootMessage('Your earlier payment went through — your QR has been created.');
        return;
      }

      if (paid && pending.purpose == 'qr_renew' &&
          pending.qrId != null && pending.hasPaymentProof) {
        await ApiClient.instance.post('/qr/${pending.qrId}/renew/verify', {
          'razorpay_order_id': pending.orderId,
          'razorpay_payment_id': pending.paymentId,
          'razorpay_signature': pending.signature,
        });
        await PendingOrderStore.clear();
        _showBootMessage('Your earlier renewal payment went through — your QR is renewed.');
        return;
      }

      if (status == 'failed' && !pending.hasPaymentProof) {
        await PendingOrderStore.clear();
      }
      // Otherwise still pending (or paid but we can't finish it from
      // here) — keep the marker and try again on the next launch.
      // PendingOrderStore.read() expires it eventually.
    } catch (e) {
      // A 4xx means the server definitively refused (e.g. vehicle
      // already registered, payment already used) — retrying on every
      // launch won't help, and support can see the payment row.
      if (e is ApiException &&
          e.statusCode != null &&
          e.statusCode! >= 400 &&
          e.statusCode! < 500 &&
          e.statusCode != 401) {
        debugPrint('[boot] reconcilePendingOrder refused by server: $e');
        await PendingOrderStore.clear();
        _showBootMessage(
            'We couldn\'t finish an earlier payment: ${e.message} '
            'Contact support if you were charged.');
        return;
      }
      debugPrint('[boot] reconcilePendingOrder skipped: $e');
    }
  }

  // Root ScaffoldMessenger so boot-time messages can show no matter which
  // screen is up. (The previous navigator key was never passed to
  // MaterialApp, so these messages were always silently dropped.)
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void _showBootMessage(String text) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 6)),
      );
    });
  }

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
      scaffoldMessengerKey: _messengerKey,
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
                      // Fresh login → signed-in user; show the ad as
                      // the first post-auth surface.
                      _showCoverAd = true;
                    });
                  },
                )
              : _biometricLocked
                  ? BiometricLockScreen(
                      key: const ValueKey('biometric-lock'),
                      onUnlocked: () => setState(() {
                        _biometricLocked = false;
                        // Biometric cleared → signed-in user is about
                        // to see the shell; show the ad first.
                        _showCoverAd = true;
                      }),
                      onSignOut: _signOutFromLock,
                    )
                  : _showCoverAd
                      ? CoverAdScreen(
                          key: const ValueKey('cover-ad'),
                          onDismiss: () {
                            if (!mounted) return;
                            setState(() => _showCoverAd = false);
                          },
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
