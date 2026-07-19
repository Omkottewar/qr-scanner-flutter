import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/login_gradient_background.dart';
import '../widgets/scale_tap.dart';

/// Shown on cold start when the user has fingerprint login enabled.
/// Auto-prompts on mount; on dismissal/failure the user can retry or escape
/// via OTP — they never get force-logged-out for a misread fingerprint.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({
    super.key,
    required this.onUnlocked,
    required this.onSignOut,
  });

  /// Called when biometric authentication succeeds. Parent should mark the
  /// app as logged-in.
  final VoidCallback onUnlocked;

  /// Called when the user gives up on biometrics and wants to sign in with
  /// OTP. Parent should clear SessionStore and show LoginScreen.
  final VoidCallback onSignOut;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _prompting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_prompting) return;
    setState(() {
      _prompting = true;
      _error = null;
    });

    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Unlock QR 4 Emergency',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      _error = _messageFor(e);
    } catch (e) {
      _error = 'Could not verify: $e';
    }

    if (!mounted) return;
    setState(() => _prompting = false);

    if (ok) {
      widget.onUnlocked();
    } else if (_error == null) {
      // User cancelled the system prompt — leave them on the lock screen so
      // they can tap Retry. Don't auto-loop, that loops the prompt forever.
      setState(() => _error = 'Verification cancelled. Tap Retry to try again.');
    }
  }

  String _messageFor(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric login is not available right now.';
      case 'NotEnrolled':
        return 'No fingerprint or face is enrolled on this device anymore.';
      case 'PasscodeNotSet':
        return 'Your device no longer has a screen lock. Set one up to use '
            'biometric login.';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return 'Too many failed attempts. Unlock your device with PIN, then '
            'tap Retry.';
      default:
        return 'Verification failed (${e.code}). Tap Retry to try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginGradientBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.55),
                      blurRadius: 50,
                      spreadRadius: -12,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.fingerprint_rounded,
                      color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your fingerprint or face to unlock QR 4 Emergency.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              ScaleTap(
                onTap: _prompting ? null : _prompt,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.55),
                        blurRadius: 40,
                        spreadRadius: -10,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _prompting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _prompting ? null : widget.onSignOut,
                child: const Text(
                  'Sign in with OTP instead',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
