// lib/providers/menu_test_provider.dart

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final menuTestProvider = StateNotifierProvider<MenuTestNotifier, MenuTestState>(
  (ref) => MenuTestNotifier(),
);

class MenuTestState {
  final Map<String, Map<String, String>> answers;
  final List<String> codes;

  MenuTestState({required this.answers, required this.codes});

  MenuTestState.initial() : answers = {}, codes = [];
}

class MenuTestNotifier extends StateNotifier<MenuTestState> {
  MenuTestNotifier() : super(MenuTestState.initial());

  Future<void> loadData(String test) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? answersData = prefs.getString('answers');
    String? codesData = prefs.getString('codes');

    state = MenuTestState(
      answers: answersData != null
          ? jsonDecode(answersData).map<String, Map<String, String>>(
              (key, value) => MapEntry(key, Map<String, String>.from(value)),
            )
          : {},
      codes: codesData != null ? List<String>.from(jsonDecode(codesData)) : [],
    );
  }
}
