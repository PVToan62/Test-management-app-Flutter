// lib/widgets/form_text_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget FormTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  bool isNumber = false,

  Function(String)? onChangedCallback,
  String? errorText,
}) {
  return TextField(
    controller: controller,
    onChanged: onChangedCallback,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      errorText: errorText,
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: errorText != null ? Colors.red : Colors.grey,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: errorText != null ? Colors.red : Colors.blue,
          width: 2.0,
        ),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2.0),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2.0),
      ),
    ),
  );
}