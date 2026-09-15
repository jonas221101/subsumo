import 'package:flutter/material.dart';

/// Eingabefeld mit einheitlicher Beschriftung/Rahmen (aus
/// `Theme.of(context).inputDecorationTheme`). Deckt die bisherigen Faelle ab:
/// einzeiliges Login-Feld und mehrzeiliger, expandierender Gutachten-Editor.
class SubsumoTextField extends StatelessWidget {
  const SubsumoTextField({
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.hintText,
    this.maxLines = 1,
    this.expands = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final String? hintText;
  final int? maxLines;
  final bool expands;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        maxLines: expands ? null : maxLines,
        expands: expands,
        textAlignVertical: expands ? TextAlignVertical.top : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          alignLabelWithHint: expands,
        ),
      );
}
