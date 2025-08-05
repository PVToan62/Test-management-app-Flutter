// lib/providers/student_test_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_test.dart';

class StudentTestsNotifier extends StateNotifier<List<StudentTest>> {
  StudentTestsNotifier() : super([]) {
    loadTests();
  }

  Future<void> loadTests() async {
    final prefs = await SharedPreferences.getInstance();
    final testJsonList = prefs.getStringList('student_tests') ?? [];
    state = testJsonList
        .map((jsonStr) => StudentTest.fromJson(jsonStr))
        .toList();
  }

  Future<void> saveTests() async {
    final prefs = await SharedPreferences.getInstance();
    final testJsonList = state.map((test) => test.toJson()).toList();
    await prefs.setStringList('student_tests', testJsonList);
  }

  void addStudentTest(StudentTest test) {
    final isExists = state.any((t) => t.testId == test.testId);
    if (!isExists) {
      state = [...state, test];
      saveTests();
    }
  }

  void removeTest(String testId) {
    state = state.where((test) => test.testId != testId).toList();
    saveTests();
  }

  void clearAll() {
    state = [];
    saveTests();
  }
}

final studentTestsProvider =
    StateNotifierProvider<StudentTestsNotifier, List<StudentTest>>(
      (ref) => StudentTestsNotifier(),
    );
