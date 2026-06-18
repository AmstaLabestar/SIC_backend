import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

/// Champ texte soft UI de l'app : label anime, icone de tete qui s'illumine au
/// focus, surface qui passe en blanc avec une ombre douce quand le champ est
/// actif, et bascule de visibilite fluide pour les mots de passe.
///
/// Concu pour login + inscription afin d'unifier l'experience de saisie.
class SicTextField extends StatefulWidget {
  const SicTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.inputFormatters,
    this.autofillHints,
    this.isPassword = false,
    this.helperText,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final List<String>? autofillHints;
  final bool isPassword;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<SicTextField> createState() => _SicTextFieldState();
}

class _SicTextFieldState extends State<SicTextField> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool _focused = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focused != _node.hasFocus) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _focused ? AppColors.primary : AppColors.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: AppTextStyles.microLabel.copyWith(
            color: _focused ? AppColors.primary : AppColors.textPrimary,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _node,
            enabled: widget.enabled,
            obscureText: widget.isPassword && _obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              filled: true,
              fillColor: _focused ? AppColors.surface : AppColors.surfaceMuted,
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(widget.icon, size: 20, color: iconColor),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          key: ValueKey(_obscure),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
