import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/error_messages.dart';
import '../../core/legal_content.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/session_store.dart';
import '../widgets/glass_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/scale_tap.dart';
import 'caller_activity_screen.dart';
import 'legal_document_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

// State is public so MainShell can trigger refresh() via GlobalKey when
// the user swings back to the Profile tab — IndexedStack keeps the
// widget mounted so initState() only fires once for the whole session.
class ProfileTabState extends State<ProfileTab> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  late final TextEditingController _mobileCtrl;

  bool _loading = true;
  bool _saving = false;
  bool _biometricEnabled = false;
  String? _loadError;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _mobileCtrl = TextEditingController();
    _load();
    _loadBiometricSetting();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _age.dispose();
    _address.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = prefs.getBool('fingerprint_login_enabled') ?? false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    // Disabling never needs biometric confirmation — the user is already in
    // an authenticated session and locking themselves out is their choice.
    if (!value) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fingerprint_login_enabled', false);
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fingerprint login disabled')),
      );
      return;
    }

    // Enabling: device must support biometrics AND the user must have at
    // least one biometric enrolled. canCheckBiometrics alone isn't enough —
    // it can return true on a device whose fingerprint sensor exists but
    // has no enrolled prints.
    String? blocker;
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        blocker = 'This device does not have a biometric sensor.';
      } else {
        final available = await _localAuth.getAvailableBiometrics();
        if (available.isEmpty) {
          blocker = 'No fingerprint or face is enrolled. Set one up in '
              'your device Settings, then try again.';
        }
      }
    } catch (e) {
      blocker = 'Could not check biometric availability: $e';
    }
    if (blocker != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(blocker)),
        );
      }
      return;
    }

    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason:
            'Confirm your fingerprint or face to enable biometric login',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_biometricErrorMessage(e))),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
      return;
    }

    if (!authenticated) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fingerprint_login_enabled', true);
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fingerprint login enabled')),
    );
  }

  String _biometricErrorMessage(PlatformException e) {
    // local_auth surfaces platform-specific error codes; translate the
    // common ones into something the user can act on.
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric login is not available on this device right now.';
      case 'NotEnrolled':
        return 'No fingerprint or face is enrolled. Set one up in your '
            'device Settings, then try again.';
      case 'PasscodeNotSet':
        return 'Set a screen-lock PIN or password in device Settings before '
            'enabling biometric login.';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return 'Too many failed attempts. Unlock your device with your PIN '
            'or password, then try again.';
      default:
        return 'Verification failed (${e.code}). Try again.';
    }
  }

  /// Public re-fetch — MainShell calls this on tab focus so a
  /// side-channel update (email verified on another device, etc.) shows
  /// up without a full app restart.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final m = await SessionStore.getMobile();
      final res = await ApiClient.instance.get('/profile');
      if (!mounted) return;
      if (res is! Map) {
        throw Exception('Unexpected server response for /profile');
      }
      setState(() {
        _mobileCtrl.text = res['mobile']?.toString() ?? m ?? '';
        _name.text = res['name']?.toString() ?? '';
        _email.text = res['email']?.toString() ?? '';
        _age.text = res['age'] != null ? '${res['age']}' : '';
        _address.text = res['address']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
      };
      final age = int.tryParse(_age.text.trim());
      if (age != null) body['age'] = age;
      await ApiClient.instance.put('/profile', body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  String get _initials {
    final n = _name.text.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatMobile(String m) {
    final s = m.replaceAll(RegExp(r'\D'), '');
    if (s.length == 10) {
      return '+91 ${s.substring(0, 5)} ${s.substring(5)}';
    }
    return '+91 $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _AmbientBg(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _loadError != null
                    ? _ProfileLoadError(message: _loadError!, onRetry: _load)
                    : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 128),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Profile',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Your account, your safety net',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: const NotificationBell(compact: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // User hero card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.6),
                                      blurRadius: 36,
                                      spreadRadius: -10,
                                      offset: const Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _name.text.trim().isEmpty
                                          ? 'Set your name'
                                          : _name.text.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_rounded,
                                            color: AppColors.textSecondary,
                                            size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatMobile(_mobileCtrl.text),
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.5,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_email.text.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.mail_rounded,
                                              color: AppColors.textSecondary,
                                              size: 12),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _email.text,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Personal info
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.person_outline_rounded,
                                      color: AppColors.amber, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'PERSONAL INFO',
                                    style: TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _Field(
                                label: 'FULL NAME',
                                controller: _name,
                                hint: 'Your full name',
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                label: 'MOBILE',
                                controller: _mobileCtrl,
                                readOnly: true,
                                locked: true,
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                label: 'EMAIL',
                                controller: _email,
                                hint: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                label: 'AGE',
                                controller: _age,
                                hint: 'Your age',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                label: 'ADDRESS',
                                controller: _address,
                                hint: 'Full address',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 24),
                              ScaleTap(
                                onTap: _saving ? null : _save,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  opacity: _saving ? 0.55 : 1,
                                  child: Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.brandGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _saving
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.55),
                                                blurRadius: 40,
                                                spreadRadius: -10,
                                                offset: const Offset(0, 18),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: _saving
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Save changes',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(Icons.check_rounded,
                                                    color: Colors.white, size: 18),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Settings
                        GlassCard(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: _buildSettingsRows(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Logout
                        ScaleTap(
                          onTap: () => widget.onLogout(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: Color(0xFFEF4444), size: 18),
                                SizedBox(width: 10),
                                Text(
                                  'Log out',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Center(
                          child: Text(
                            'v1.0.5 · QR 4 Emergency',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSettingsRows() {
    final rows = <_SettingRow>[
      _SettingRow(
        icon: Icons.fingerprint_rounded,
        color: const Color(0xFF3B82F6),
        title: 'Fingerprint Login',
        sub: 'Use biometrics to unlock',
        toggle: true,
      ),
      _SettingRow(
        icon: Icons.phone_in_talk_rounded,
        color: const Color(0xFF06B6D4),
        title: 'Caller Activity',
        sub: 'Who has called your QR — block spam',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CallerActivityScreen(),
            ),
          );
        },
      ),
      _SettingRow(
        icon: Icons.info_outline_rounded,
        color: AppColors.amber,
        title: 'About QR 4 Emergency',
        sub: 'Our mission and story',
        onTap: () => _openLegal(LegalContent.about),
      ),
      _SettingRow(
        icon: Icons.description_outlined,
        color: const Color(0xFF10B981),
        title: 'Terms & Conditions',
        sub: 'Read the fine print',
        onTap: () => _openLegal(LegalContent.termsAndConditions),
      ),
      _SettingRow(
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFFEF4444),
        title: 'Privacy Policy',
        sub: 'How we protect your data',
        onTap: () => _openLegal(LegalContent.privacyPolicy),
      ),
      _SettingRow(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFB923C),
        title: 'Disclaimer',
        sub: 'What this app is and isn\'t',
        onTap: () => _openLegal(LegalContent.disclaimer),
      ),
      _SettingRow(
        icon: Icons.chat_bubble_outline_rounded,
        color: AppColors.primary,
        title: 'Contact Us',
        sub: 'Support, billing, grievance',
        onTap: () => _openLegal(LegalContent.contactUs),
      ),
    ];

    final widgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      widgets.add(_buildRow(r));
      if (i < rows.length - 1) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildRow(_SettingRow r) {
    return ScaleTap(
      onTap: r.onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: r.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: r.color.withValues(alpha: 0.24)),
              ),
              child: Icon(r.icon, color: r.color, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.sub,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (r.toggle == true)
              _BrandSwitch(
                value: _biometricEnabled,
                onChanged: _toggleBiometrics,
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SettingRow {
  _SettingRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    this.onTap,
    this.toggle = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool toggle;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.readOnly = false,
    this.locked = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool readOnly;
  final bool locked;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2236),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                    filled: false,
                  ),
                ),
              ),
              if (locked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'LOCKED',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandSwitch extends StatelessWidget {
  const _BrandSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          gradient: value ? AppColors.brandGradient : null,
          color: value ? null : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              top: 2,
              left: value ? 22 : 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 56, color: Color(0xFFEF4444)),
        const SizedBox(height: 16),
        const Text(
          'Could not load profile',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            label: const Text(
              'Retry',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmbientBg extends StatelessWidget {
  const _AmbientBg();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF06090F))),
          Positioned(
            top: -120,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
