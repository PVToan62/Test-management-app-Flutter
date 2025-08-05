// lib/utils/dialog_utils.dart

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void showLoadingDialog() {
  final context = rootNavigatorKey.currentContext;
  if (context != null) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }
}

void hideLoadingDialog() {
  final navigator = rootNavigatorKey.currentState;
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
  }
}
