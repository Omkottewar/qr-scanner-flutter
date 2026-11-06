import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/login_gradient_background.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobile = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  bool _focused = false;
  // Only India is actually wired to Exotel + DLT templates right now. The
  // picker lists other countries for visual polish, but tapping them
  // shows a "coming soon" toast and leaves India selected.
  _Country _country = _Countries.india;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _mobile.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _valid => _mobile.text.replaceAll(RegExp(r'\D'), '').length == 10;

  Future<void> _openCountryPicker() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(selected: _country),
    );
    if (picked == null || picked.dialCode == _country.dialCode) return;
    // Only India is wired to the backend — any other pick is informational
    // and resets to India.
    if (!picked.supported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            '${picked.name} support is coming soon. Continuing with India.',
          ),
        ));
      return;
    }
    setState(() => _country = picked);
  }

  Future<void> _sendOtp() async {
    final m = _mobile.text.trim().replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^[0-9]{10}$').hasMatch(m)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/auth/login', {'mobile': m}, auth: false);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              OtpScreen(mobile: m, onLoggedIn: widget.onLoggedIn),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginGradientBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand badge + heading
            Center(
              child: Container(
                width: 88,
                height: 88,
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
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/nayak.jpeg',
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(Icons.shield_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'QR 4 Emergency',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'BE NAYAK',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Stay connected with your loved ones,\nwherever you go.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            // Phone input glass card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MOBILE NUMBER',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _focused
                            ? AppColors.primary
                            : AppColors.hairline,
                        width: _focused ? 1.5 : 1,
                      ),
                      boxShadow: _focused
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                spreadRadius: 4,
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: -8,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _openCountryPicker,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                            child: Row(
                              children: [
                                Text(_country.flag,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  _country.dialCode,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: AppColors.hairline,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _mobile,
                            focusNode: _focus,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              counterText: '',
                              filled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            EaPrimaryButton(
              label: 'Verify & Continue',
              icon: Icons.arrow_forward_rounded,
              loading: _loading,
              onPressed: (_loading || !_valid) ? null : _sendOtp,
            ),
            const SizedBox(height: 24),
            // Encrypted banner
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: AppColors.amber, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your emergency contact details stay encrypted and are shared only when your QR code is scanned.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Trust row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _TrustBadge(icon: Icons.lock_rounded, label: 'PRIVATE'),
                _TrustBadge(icon: Icons.bolt_rounded, label: 'INSTANT'),
                _TrustBadge(icon: Icons.shield_rounded, label: 'SECURE'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Icon(icon, color: AppColors.amber, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Country model + static list. Only India is `supported = true` right now
// — Exotel's dial-plan, our DLT templates and the OTP-via-SMS integration
// are all India-only. Other entries render for visual polish and future
// expansion; selecting them shows a "coming soon" toast.
// -----------------------------------------------------------------------------
class _Country {
  const _Country({
    required this.name,
    required this.flag,
    required this.dialCode,
    this.supported = false,
  });
  final String name;
  final String flag;
  final String dialCode;
  final bool supported;
}

abstract final class _Countries {
  static const india = _Country(
    name: 'India',
    flag: '🇮🇳',
    dialCode: '+91',
    supported: true,
  );

  // Ordered alphabetically for predictable scan; India stays pinned at the
  // top because it's the only supported entry.
  static const all = <_Country>[
    india,
    _Country(name: 'Australia', flag: '🇦🇺', dialCode: '+61'),
    _Country(name: 'Bangladesh', flag: '🇧🇩', dialCode: '+880'),
    _Country(name: 'Canada', flag: '🇨🇦', dialCode: '+1'),
    _Country(name: 'China', flag: '🇨🇳', dialCode: '+86'),
    _Country(name: 'France', flag: '🇫🇷', dialCode: '+33'),
    _Country(name: 'Germany', flag: '🇩🇪', dialCode: '+49'),
    _Country(name: 'Indonesia', flag: '🇮🇩', dialCode: '+62'),
    _Country(name: 'Italy', flag: '🇮🇹', dialCode: '+39'),
    _Country(name: 'Japan', flag: '🇯🇵', dialCode: '+81'),
    _Country(name: 'Malaysia', flag: '🇲🇾', dialCode: '+60'),
    _Country(name: 'Nepal', flag: '🇳🇵', dialCode: '+977'),
    _Country(name: 'Netherlands', flag: '🇳🇱', dialCode: '+31'),
    _Country(name: 'New Zealand', flag: '🇳🇿', dialCode: '+64'),
    _Country(name: 'Pakistan', flag: '🇵🇰', dialCode: '+92'),
    _Country(name: 'Philippines', flag: '🇵🇭', dialCode: '+63'),
    _Country(name: 'Russia', flag: '🇷🇺', dialCode: '+7'),
    _Country(name: 'Saudi Arabia', flag: '🇸🇦', dialCode: '+966'),
    _Country(name: 'Singapore', flag: '🇸🇬', dialCode: '+65'),
    _Country(name: 'South Africa', flag: '🇿🇦', dialCode: '+27'),
    _Country(name: 'South Korea', flag: '🇰🇷', dialCode: '+82'),
    _Country(name: 'Spain', flag: '🇪🇸', dialCode: '+34'),
    _Country(name: 'Sri Lanka', flag: '🇱🇰', dialCode: '+94'),
    _Country(name: 'Thailand', flag: '🇹🇭', dialCode: '+66'),
    _Country(name: 'Turkey', flag: '🇹🇷', dialCode: '+90'),
    _Country(name: 'UAE', flag: '🇦🇪', dialCode: '+971'),
    _Country(name: 'United Kingdom', flag: '🇬🇧', dialCode: '+44'),
    _Country(name: 'United States', flag: '🇺🇸', dialCode: '+1'),
    _Country(name: 'Vietnam', flag: '🇻🇳', dialCode: '+84'),
  ];
}

// Bottom-sheet picker. Scrollable list of flag + name + dial code rows
// with an inline search field. Unsupported rows get a "Coming soon"
// subtitle but stay tappable so the user sees the toast rather than a
// dead control.
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});
  final _Country selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Country> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _Countries.all;
    return _Countries.all.where((c) {
      return c.name.toLowerCase().contains(q) || c.dialCode.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select country',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                    ),
                    hintText: 'Search country or code',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.hairline),
                  itemBuilder: (context, i) {
                    final c = _filtered[i];
                    final isSelected =
                        widget.selected.dialCode == c.dialCode &&
                            widget.selected.name == c.name;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Text(c.flag,
                          style: const TextStyle(fontSize: 22)),
                      title: Text(
                        c.name,
                        style: TextStyle(
                          color: c.supported
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: c.supported
                          ? null
                          : const Text(
                              'Coming soon',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.dialCode,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_rounded,
                                color: AppColors.primary, size: 20),
                          ],
                        ],
                      ),
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
