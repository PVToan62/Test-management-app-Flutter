// lib/providers/teacher_user.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_management_app/widgets/toast.dart';

import '../screens/add_test_form.dart';
import '../utils/dialog_utils.dart';

final teacherUserProvider = StateNotifierProvider<TeacherUser, List<String>>((
  ref,
) {
  return TeacherUser();
});

final selectionModeProvider = StateProvider<bool>((ref) => false);
final selectedItemsProvider =
    StateNotifierProvider<SelectedItemsNotifier, List<bool>>((ref) {
      return SelectedItemsNotifier();
    });

final selectedTestTeacherProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

class TeacherUser extends StateNotifier<List<String>> {
  TeacherUser() : super([]) {
    loadTestsTeacher();
  }

  Future<void> loadTestsTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('tests') ?? [];
  }

  Future<void> saveTestsTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tests', state);
  }

  void deleteSelectedTests(List<bool> selected) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (!selected[i]) state[i],
    ];
    saveTestsTeacher();
  }

  void sortTestsTeacher(String criteria) {
    List<String> sortedTests = [...state];
    if (criteria == 'lớp') {
      sortedTests.sort((a, b) => a.split('_')[1].compareTo(b.split('_')[1]));
    }
    if (criteria == 'môn học') {
      sortedTests.sort((a, b) => a.split('_')[0].compareTo(b.split('_')[0]));
    }
    if (criteria == 'ngày tạo') {
      sortedTests.sort((b, a) => a.split('_')[4].compareTo(b.split('_')[4]));
    }
    state = sortedTests;
  }

  void addTestTeacher({required BuildContext context, required WidgetRef ref}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: AddTestForm(
            onSubmit:
                (
                  String subject,
                  String clazz,
                  String questions,
                  String duration,
                  String createTime,
                  String testId,
                ) {
                  final newTestString =
                      '${subject}_${clazz}_${questions}_${duration}_${createTime}_$testId';

                  final newTests = [...state, newTestString];
                  state = newTests;

                  final selectedNotifier = ref.read(
                    selectedItemsProvider.notifier,
                  );
                  final currentSelected = selectedNotifier.state;
                  final newSelected = [...currentSelected, false];
                  selectedNotifier.state = newSelected;

                  saveTestsTeacher();

                  Navigator.of(context).pop();

                  showToast(message: 'Tạo bài kiểm tra thành công');
                },
          ),
        );
      },
    );
  }

  Future<void> publishTest({
    required BuildContext context,
    required String testId,
    required String testKey,
    required String clazz,
    required String subject,
    required String questions,
    required String duration,
    required String createTime,
    required void Function({required String message}) showToast,
  }) async {
    final supabase = Supabase.instance.client;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    showLoadingDialog();

    List<String>? savedCodes = prefs.getStringList('codes_$testKey');
    if (savedCodes == null || savedCodes.isEmpty) {
      hideLoadingDialog();
      showToast(message: 'Không tìm thấy mã đề!');
      return;
    }

    String? answersJson = prefs.getString('answers_$testKey');
    if (answersJson == null) {
      hideLoadingDialog();
      showToast(message: 'Không tìm thấy đáp án!');
      return;
    }

    Map<String, Map<String, String>> answersMap =
        Map<String, Map<String, String>>.from(
          jsonDecode(
            answersJson,
          ).map((key, value) => MapEntry(key, Map<String, String>.from(value))),
        );

    for (String code in savedCodes) {
      final answerMap = answersMap[code];

      if (answerMap == null) {
        if (context.mounted) {
          showToast(message: 'Bỏ qua mã đề $code vì không tìm thấy đáp án.');
        }
        continue;
      }

      final hasRealAnswers = answerMap.values.any((a) => a.trim().isNotEmpty);
      if (!hasRealAnswers) {
        if (context.mounted) {
          showToast(message: 'Bỏ qua mã đề $code vì chưa có đáp án.');
        }
        continue;
      }

      final imageKey = '${testKey}_${code}_images';
      List<String> imagePaths = prefs.getStringList(imageKey) ?? [];
      List<String> imageUrls = [];

      for (String path in imagePaths) {
        final file = File(path);
        final fileName = path.split('/').last;
        final storagePath = '$testId/$code/$fileName';

        await supabase.storage
            .from('test-images')
            .upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrl = supabase.storage
            .from('test-images')
            .getPublicUrl(storagePath);
        imageUrls.add(publicUrl);
      }

      await supabase.from('test_management_app').upsert({
        'tests': '${clazz}_$subject',
        'test_id': testId,
        'questions': int.parse(questions),
        'duration': int.parse(duration),
        'created_at': createTime,
        'published_at': DateTime.now().toIso8601String(),
        'codes': code,
        'answers': answerMap,
        'image_urls': imageUrls,
      });
    }

    hideLoadingDialog();
    showToast(message: 'Phát bài thành công!');

    List<String> publishedTests = prefs.getStringList('published_tests') ?? [];
    if (!publishedTests.contains(testId)) {
      publishedTests.add(testId);
      await prefs.setStringList('published_tests', publishedTests);
    }
  }
}

class SelectedItemsNotifier extends StateNotifier<List<bool>> {
  SelectedItemsNotifier() : super([]);

  void initialize(int length) {
    if (state.length != length) {
      state = List<bool>.filled(length, false);
    }
  }

  void toggle(int index) {
    if (index >= 0 && index < state.length) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) !state[i] else state[i],
      ];
    }
  }

  void selectAll(bool select) {
    state = List<bool>.filled(state.length, select);
  }

  void clear() {
    state = List<bool>.filled(state.length, false);
  }
}
