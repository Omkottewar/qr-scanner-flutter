import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class EaTextField extends StatefulWidget {
  const EaTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.suffix,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.labelStyle,
    this.labelAlignment,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  // Optional overrides — when null the field falls back to the input
  // theme's label style + left alignment (the existing default used by
  // every other form on the app). Passed in from create_qr_form_screen's
  // Family Contacts card so those labels can render bigger/centered
  // without changing every other field's appearance.
  final TextStyle? labelStyle;
  final TextAlign? labelAlignment;

  @override
  State<EaTextField> createState() => _EaTextFieldState();
}

class _EaTextFieldState extends State<EaTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

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
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          SizedBox(
            width: double.infinity,
            child: Text(
              widget.label!,
              textAlign: widget.labelAlignment,
              style: widget.labelStyle ??
                  Theme.of(context).inputDecorationTheme.labelStyle,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: widget.keyboardType,
              readOnly: widget.readOnly,
              enabled: widget.enabled,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              validator: widget.validator,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
              decoration: InputDecoration(
                counterText: '', // hide the maxLength "0/10" counter
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        child: Icon(
                          widget.prefixIcon,
                          color: _focused
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      )
                    : null,
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                suffixIcon: widget.suffix,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
