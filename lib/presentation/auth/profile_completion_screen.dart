import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/ea_text_field.dart';
import '../widgets/login_gradient_background.dart';

// Shown once, immediately after OTP verify, for accounts that have no
// display name on record. Mobile is already known (that's how we logged
// in), so the form asks only Name (required) and Email (optional).
// Submitting hits PUT /profile and then routes into the main shell.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({
    super.key,
    required this.mobile,
    required this.onCompleted,
    this.initialName = '',
    this.initialEmail = '',
  });

  final String mobile;
  final String initialName;
  final String initialEmail;
  final VoidCallback onCompleted;

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
      };
      final emailTrim = _email.text.trim();
      if (emailTrim.isNotEmpty) body['email'] = emailTrim;
      await ApiClient.instance.put('/profile', body);
      if (!mounted) return;
      // Pop back to the first route (LoginScreen at '/') BEFORE we flip
      // _loggedIn in the parent. If we don't, this screen stays on top
      // of the Navigator stack and covers the freshly-mounted MainShell,
      // so tapping Continue would look like it does nothing.
      final nav = Navigator.of(context);
      nav.popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCompleted();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginGradientBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.55),
                            blurRadius: 42,
                            spreadRadius: -12,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 38),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to QR 4 Emergency',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Just one detail before we get started — how should we address you?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Mobile is already known — shown here as a read-only
                  // confirmation so the user knows which number they're
                  // attaching this profile to.
                  EaTextField(
                    label: 'Mobile Number',
                    hint: widget.mobile,
                    controller: TextEditingController(text: widget.mobile),
                    prefixIcon: Icons.phone_android_rounded,
                    readOnly: true,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  EaTextField(
                    controller: _name,
                    label: 'Full Name *',
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Name is required';
                      if (s.length < 2) return 'Please enter your full name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  EaTextField(
                    controller: _email,
                    label: 'Email (optional)',
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null; // optional
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  EaPrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
