import 'package:flutter/material.dart';

/// Styled text field with large touch targets and clear labels.
class BfTextField extends StatelessWidget {
  const BfTextField({
    required this.label,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        autofocus: autofocus,
        enabled: enabled,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
