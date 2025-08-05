// lib/providers/student_user.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_test.dart';
import '../screens/get_test_form.dart';
import '../providers/student_test_provider.dart';
import '../utils/dialog_utils.dart';

final studentUserProvider = StateNotifierProvider<StudentUser, List<String>>((
    ref,
    ) {
  return StudentUser(ref);
});

class StudentUser extends StateNotifier<List<String>> {
  final Ref ref;

  StudentUser(this.ref) : super([]) {
    _loadTests();
  }

  Future<void> _loadTests() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('tests') ?? [];
  }

  void getTest({
    required BuildContext context,
    required void Function({required String message}) showToast,
  }) {
    final existingTestIds = ref.read(studentTestsProvider).map((test) => test.testId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: GetTestForm(
            onSubmit: (String testId) async {
              return await _findTest(testId: testId, showToast: showToast);
            },
            existingTestIds: existingTestIds,
          ),
        );
      },
    );
  }

  Future<String?> _findTest({
    required String testId,
    required void Function({required String message}) showToast,
  }) async {
    showLoadingDialog(); // Hiển thị loading overlay

    try {
      final response = await Supabase.instance.client
          .from('test_management_app')
          .select()
          .eq('test_id', testId);

      final List data = response;

      hideLoadingDialog(); // Ẩn loading overlay sau khi có kết quả

      if (data.isNotEmpty) {
        final random = Random();
        final randomIndex = random.nextInt(data.length);
        final test = data[randomIndex];

        final testsField = test['tests'] as String;
        final subjectClass = testsField.split('_');
        final clazz = subjectClass[0];
        final subject = subjectClass[1];
        final questions = test['questions'].toString();
        final duration = test['duration'].toString();
        final code = test['codes'].toString();

        final List<String> imageUrls = (test['image_urls'] ?? [])
            .map<String>((e) => e.toString())
            .toList();

        final testObj = StudentTest(
          clazz: clazz,
          subject: subject,
          code: code,
          questionCount: questions,
          duration: duration,
          testId: testId,
          imageUrls: imageUrls,
        );

        final testsNotifier = ref.read(studentTestsProvider.notifier);
        final isExists = ref
            .read(studentTestsProvider)
            .any((t) => t.testId == testId);

        if (!isExists) {
          testsNotifier.addStudentTest(testObj);
          showToast(message: 'Nhận bài thành công (Mã đề: $code)');
          return null;
        } else {
          return 'Bài kiểm tra đã tồn tại';
        }
      } else {
        return 'Không tìm thấy bài kiểm tra';
      }
    } catch (e) {
      hideLoadingDialog();
      return 'Lỗi: $e';
    }
  }
}