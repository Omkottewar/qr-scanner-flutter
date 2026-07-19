import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../widgets/ea_card.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/ea_text_field.dart';
import '../widgets/info_banner.dart';
import '../widgets/scale_tap.dart';

// Slash-grouped so the picker shows 5 pill buttons. Legacy singular values
// (Father / Mother / Sister / Brother) were rewritten by migration 018;
// _normalizeRelation() below maps anything unexpected onto the closest new
// group so an old row loaded from the API doesn't blank out the picker.
const _relations = [
  'Father/Mother',
  'Sister/Brother',
  'Husband/Wife',
  'Son/Daughter',
  'Other',
];

String _normalizeRelation(String raw) {
  final s = raw.trim();
  if (_relations.contains(s)) return s;
  if (s == 'Father' || s == 'Mother') return 'Father/Mother';
  if (s == 'Sister' || s == 'Brother') return 'Sister/Brother';
  return 'Other';
}

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
  // "Call Owner" on the alert page. Edits to qrdata.mobile only; the
  // user's account login mobile is intentionally left alone.
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
            relation: _normalizeRelation(m['relation']?.toString() ?? ''),
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
    if (_contacts.length >= 5) return;
    HapticFeedback.lightImpact();
    setState(() => _contacts.add(_ContactRow()));
  }

  void _removeContact(int index) {
    if (_contacts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one emergency contact is required')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      final c = _contacts.removeAt(index);
      c.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      // Owner-phone edit was dropped — the field is read-only, so we only
      // ever push family changes now.
      final payload = {
        'family': _contacts
            .map((c) => {
                  'name': c.name.text.trim(),
                  'phone':
                      c.phone.text.trim().replaceAll(RegExp(r'\s'), ''),
                  'relation': c.relation,
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _AmbientBg(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  ownerName: widget.ownerName,
                  vehicleNumber: widget.vehicleNumber,
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : _error != null
                          ? _ErrorState(message: _error!, onRetry: _load)
                          : Form(
                              key: _formKey,
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 6, 20, 28),
                                children: [
                                  EaCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Owner Phone',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800),
                                            ),
                                            const SizedBox(width: 8),
                                            // Locked chip so the greyed-out
                                            // field's disabled state has a
                                            // clear "why" affordance rather
                                            // than looking like a bug.
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.textTertiary
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.lock_rounded,
                                                    size: 10,
                                                    color: AppColors
                                                        .textTertiary,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'LOCKED',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .textTertiary,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'The number that gets called when a bystander taps "Call Owner". Locked to the number you registered with — contact support to change it.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  height: 1.4),
                                        ),
                                        const SizedBox(height: 12),
                                        // Read-only. Editing was too easy a
                                        // way for a compromised session to
                                        // hijack the "Call Owner" bridge.
                                        EaTextField(
                                          controller: _ownerPhone,
                                          label: 'Phone Number',
                                          hint: '10-digit mobile',
                                          keyboardType: TextInputType.phone,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          readOnly: true,
                                          enabled: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const InfoBanner(
                                    text:
                                        'These are the people contacted when someone scans your QR. Up to 5 allowed.',
                                  ),
                                  const SizedBox(height: 18),
                                  ...List.generate(_contacts.length, (i) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: _ContactCard(
                                        index: i,
                                        contact: _contacts[i],
                                        canRemove: _contacts.length > 1,
                                        onRemove: () => _removeContact(i),
                                        onRelationChanged: (v) {
                                          setState(() =>
                                              _contacts[i].relation = v);
                                        },
                                      ),
                                    );
                                  }),
                                  if (_contacts.length < 5)
                                    _AddContactButton(onTap: _addContact),
                                  const SizedBox(height: 14),
                                  Center(
                                    child: Text(
                                      '${_contacts.length}/5 contacts',
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
                if (!_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
        ],
      ),
    );
  }
}

class _ContactRow {
  _ContactRow({String name = '', String phone = '', this.relation = 'Father/Mother'})
      : name = TextEditingController(text: name),
        phone = TextEditingController(text: phone);

  final TextEditingController name;
  final TextEditingController phone;
  String relation;

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

class _AmbientBg extends StatelessWidget {
  const _AmbientBg();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF101729), Color(0xFF06090F)],
                stops: [0, 0.45],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.ownerName,
    required this.vehicleNumber,
    required this.onBack,
  });

  final String ownerName;
  final String vehicleNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.glassFill,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.glassStroke),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'EDIT CONTACTS',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ownerName.isEmpty ? vehicleNumber : ownerName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ownerName.isNotEmpty)
                  Text(
                    vehicleNumber,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.index,
    required this.contact,
    required this.canRemove,
    required this.onRemove,
    required this.onRelationChanged,
  });

  final int index;
  final _ContactRow contact;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<String> onRelationChanged;

  @override
  Widget build(BuildContext context) {
    return EaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradientSubtle,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Contact ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (canRemove)
                ScaleTap(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: AppColors.red, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          EaTextField(
            controller: contact.name,
            label: 'Name *',
            hint: 'Contact name',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          EaTextField(
            controller: contact.phone,
            label: 'Phone Number *',
            hint: '10-digit mobile number',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_rounded,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) {
                return 'Enter a valid 10-digit number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Relationship *',
            style: Theme.of(context).inputDecorationTheme.labelStyle,
          ),
          const SizedBox(height: 8),
          _RelationPicker(
            value: contact.relation,
            onChanged: onRelationChanged,
          ),
        ],
      ),
    );
  }
}

class _RelationPicker extends StatelessWidget {
  const _RelationPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _relations.map((r) {
        final selected = r == value;
        return ScaleTap(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(r);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.brandGradient : null,
              color: selected ? null : AppColors.inputFill,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : AppColors.hairline,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              r,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

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
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
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
              decoration: BoxDecoration(
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
                fontWeight: FontWeight.w700,
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
