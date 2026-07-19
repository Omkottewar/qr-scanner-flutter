import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/session_store.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/login_gradient_background.dart';
import 'profile_completion_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.mobile, required this.onLoggedIn});

  final String mobile;
  final VoidCallback onLoggedIn;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 4;
  static const int _resendSeconds = 28;

  final List<TextEditingController> _ctrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(_otpLength, (_) => FocusNode());
  bool _loading = false;
  int _remaining = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();
  bool get _complete => _ctrls.every((c) => c.text.length == 1);

  String _formatMobile(String m) {
    final s = m.replaceAll(RegExp(r'\D'), '');
    if (s.length == 10) {
      return '+91 ${s.substring(0, 5)} ${s.substring(5)}';
    }
    return '+91 $s';
  }

  Future<void> _resend() async {
    if (_remaining > 0) return;
    HapticFeedback.selectionClick();
    try {
      await ApiClient.instance
          .post('/auth/login', {'mobile': widget.mobile}, auth: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent')),
        );
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      }
    }
  }

  Future<void> _verify() async {
    if (!_complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the full 4-digit code')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    var navigatedAway = false;
    try {
      final res = await ApiClient.instance.post(
        '/auth/verify-otp',
        {'mobile': widget.mobile, 'otp': _otp},
        auth: false,
      );
      if (!mounted) return;
      if (res is! Map) throw Exception('Invalid server response');
      final map = Map<String, dynamic>.from(res);
      final token = (map['token'] ?? map['access_token'])?.toString();
      if (token == null || token.isEmpty) throw Exception('No token in response');

      final navigator = Navigator.of(context);
      await SessionStore.saveSession(token: token, mobile: widget.mobile);
      if (!mounted) return;

      // Branch on the returned user profile: first-time users (no name on
      // record) get pushed to the profile-completion screen before the
      // main shell shows up. Returning users go straight into the app.
      final user = map['user'] is Map ? Map<String, dynamic>.from(map['user'] as Map) : const <String, dynamic>{};
      final existingName = (user['name']?.toString() ?? '').trim();
      final existingEmail = (user['email']?.toString() ?? '').trim();

      if (existingName.isEmpty) {
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ProfileCompletionScreen(
              mobile: widget.mobile,
              initialName: existingName,
              initialEmail: existingEmail,
              onCompleted: widget.onLoggedIn,
            ),
          ),
        );
        navigatedAway = true;
      } else {
        navigator.pop();
        navigatedAway = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onLoggedIn();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      }
    } finally {
      if (mounted && !navigatedAway) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginGradientBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back button glass circle
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.textPrimary, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Brand badge
            Center(
              child: Container(
                width: 76,
                height: 76,
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
                  child: Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Verify your number',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Code sent to '),
                  TextSpan(
                    text: _formatMobile(widget.mobile),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            // OTP boxes glass card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (i) {
                      return _OtpBox(
                        controller: _ctrls[i],
                        focusNode: _nodes[i],
                        onChanged: (v) {
                          if (v.length == 1 && i < _otpLength - 1) {
                            _nodes[i + 1].requestFocus();
                          } else if (v.isEmpty && i > 0) {
                            _nodes[i - 1].requestFocus();
                          }
                          setState(() {});
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            EaPrimaryButton(
              label: 'Verify & Continue',
              icon: Icons.lock_rounded,
              loading: _loading,
              onPressed: (_loading || !_complete) ? null : _verify,
            ),
            const SizedBox(height: 24),
            Center(
              child: _remaining > 0
                  ? Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(text: 'Resend code in '),
                          TextSpan(
                            text:
                                '0:${_remaining.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _resend,
                      child: const Text(
                        'Resend code',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2236),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.10),
          width: filled ? 1.5 : 1,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  spreadRadius: 4,
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  blurRadius: 20,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.0,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: const InputDecoration(
          counterText: '',
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
