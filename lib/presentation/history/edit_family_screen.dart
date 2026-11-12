import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/ea_text_field.dart';
import '../widgets/info_banner.dart';
import '../widgets/qr_loader.dart';
import '../widgets/scale_tap.dart';

class EditFamilyScreen extends StatefulWidget {
  const EditFamilyScreen({
    super.key,
    required this.qrId,
    required this.ownerName,
    required this.vehicleNumber,
    required this.ownerPhone,
  });

  final int qrId;
  final String ownerName;
  final String vehicleNumber;
  final String ownerPhone;

  @override
  State<EditFamilyScreen> createState() => _EditFamilyScreenState();
}

class _EditFamilyScreenState extends State<EditFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_ContactRow> _contacts = [];
  // Owner phone — the number that gets bridged when a bystander taps
  // "Call Owner" on the alert page. Read-only; editing it from here would
  // let a compromised session hijack the bridge target.
  late final TextEditingController _ownerPhone;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownerPhone = TextEditingController(text: widget.ownerPhone);
    _load();
  }

  @override
  void dispose() {
    _ownerPhone.dispose();
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get('/qr/${widget.qrId}/family');
      final items = (res is Map ? res['items'] : null) as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        for (final c in _contacts) {
          c.dispose();
        }
        _contacts.clear();
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          _contacts.add(_ContactRow(
            name: m['name']?.toString() ?? '',
            phone: m['phone']?.toString() ?? '',
          ));
        }
        if (_contacts.isEmpty) _contacts.add(_ContactRow());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.friendly(e);
        _loading = false;
      });
    }
  }

  void _addContact() {
    if (_contacts.length >= 3) return;
    HapticFeedback.lightImpact();
    setState(() => _contacts.add(_ContactRow()));
  }

  void _removeContact(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      final c = _contacts.removeAt(index);
      c.dispose();
      // Always keep at least one empty slot visible so the user has a
      // typing surface — the "Add contact" button is clearer when there's
      // already a row showing it's safe to fill one in.
      if (_contacts.isEmpty) _contacts.add(_ContactRow());
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      // Every row is optional — drop any row where both name and phone are
      // blank. Matches how /qr/create accepts zero contacts.
      final rows = _contacts.where((c) {
        final n = c.name.text.trim();
        final p = c.phone.text.trim();
        return n.isNotEmpty || p.isNotEmpty;
      }).toList();
      final payload = {
        'family': rows
            .map((c) => {
                  'name': c.name.text.trim(),
                  'phone':
                      c.phone.text.trim().replaceAll(RegExp(r'\s'), ''),
                })
            .toList(),
      };
      await ApiClient.instance.put('/qr/${widget.qrId}/family', payload);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency contacts updated')),
      );
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
    final subtitle = widget.ownerName.isNotEmpty
        ? '${widget.ownerName} · ${widget.vehicleNumber}'
        : widget.vehicleNumber;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit Contacts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: QrLoader(size: 20))
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Owner ────────────────────────────────
                                const _SectionBanner(
                                  icon: Icons.person_rounded,
                                  title: 'Owner',
                                ),
                                const SizedBox(height: 14),
                                _FormCard(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lock_rounded,
                                          size: 14,
                                          color: AppColors.textTertiary,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'LOCKED',
                                          style: TextStyle(
                                            color: AppColors.textTertiary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'The number that gets called when a bystander taps "Call Owner". Locked to the number you registered with — contact support to change it.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _FormField(
                                      icon: Icons.phone_android_rounded,
                                      label: 'Owner Phone',
                                      child: EaTextField(
                                        controller: _ownerPhone,
                                        keyboardType: TextInputType.phone,
                                        prefixIcon:
                                            Icons.lock_outline_rounded,
                                        readOnly: true,
                                        enabled: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // ── Emergency Contacts ───────────────────
                                const _SectionBanner(
                                  icon: Icons.groups_rounded,
                                  title: 'Emergency Contacts',
                                ),
                                const SizedBox(height: 14),
                                const InfoBanner(
                                  text:
                                      'These are the people contacted when someone scans your QR. Up to 3 allowed — all optional.',
                                ),
                                const SizedBox(height: 14),
                                ...List.generate(_contacts.length, (i) {
                                  final c = _contacts[i];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 14),
                                    child: _ContactCard(
                                      onRemove: () => _removeContact(i),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _FormField(
                                            icon:
                                                Icons.person_outline_rounded,
                                            label: 'Name',
                                            child: EaTextField(
                                              controller: c.name,
                                              hint: 'Enter contact name',
                                              textCapitalization:
                                                  TextCapitalization.words,
                                              validator: (v) {
                                                final s = (v ?? '').trim();
                                                if (s.isEmpty &&
                                                    c.phone.text
                                                        .trim()
                                                        .isNotEmpty) {
                                                  return 'Name is required when phone is filled';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          _FormField(
                                            icon:
                                                Icons.phone_android_rounded,
                                            label: 'Mobile Number',
                                            child: EaTextField(
                                              controller: c.phone,
                                              hint: '10-digit mobile number',
                                              keyboardType:
                                                  TextInputType.phone,
                                              maxLength: 10,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              validator: (v) {
                                                final s = (v ?? '').trim();
                                                if (s.isEmpty &&
                                                    c.name.text
                                                        .trim()
                                                        .isNotEmpty) {
                                                  return 'Phone is required when name is filled';
                                                }
                                                if (s.isNotEmpty &&
                                                    !RegExp(r'^[0-9]{10}$')
                                                        .hasMatch(s)) {
                                                  return 'Enter a valid 10-digit number';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                if (_contacts.length < 3)
                                  _AddContactButton(onTap: _addContact),
                                const SizedBox(height: 10),
                                Center(
                                  child: Text(
                                    '${_contacts.length}/3 contacts',
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: EaPrimaryButton(
                          label: 'Save Changes',
                          icon: Icons.check_rounded,
                          loading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ContactRow {
  _ContactRow({String name = '', String phone = ''})
      : name = TextEditingController(text: name),
        phone = TextEditingController(text: phone);

  final TextEditingController name;
  final TextEditingController phone;

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

// -----------------------------------------------------------------------------
// Red section banner — mirrors the one used in create_qr_form_screen.dart so
// the edit flow reads as part of the same family. Icon + divider + bold
// white title on a red-maroon gradient.
// -----------------------------------------------------------------------------
class _SectionBanner extends StatelessWidget {
  const _SectionBanner({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB71218), Color(0xFF8A0A10)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Container(
            width: 1.5,
            height: 26,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// White content card used directly below a `_SectionBanner`.
// -----------------------------------------------------------------------------
class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Icon + bold label on top, input below.
// -----------------------------------------------------------------------------
class _FormField extends StatelessWidget {
  const _FormField({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Plain white card wrapping the two fields for a single contact. A small
// red "remove" chip sits in the top-right so users can clear a row.
// -----------------------------------------------------------------------------
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ScaleTap(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: AppColors.red, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dashed-feel light button for adding another contact row.
// -----------------------------------------------------------------------------
class _AddContactButton extends StatelessWidget {
  const _AddContactButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add another contact',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline_rounded,
            size: 56, color: AppColors.red),
        const SizedBox(height: 16),
        Text(
          'Failed to load contacts',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
