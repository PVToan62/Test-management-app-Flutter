// lib/providers/student_provider.dart

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentListController extends StateNotifier<StudentListState> {
  StudentListController() : super(StudentListState());

  void toggleSelectionMode(bool value) {
    state = state.copyWith(isSelectionMode: value);
  }

  void toggleSelectStudent(int index) {
    final updatedSelected = [...state.selected];
    updatedSelected[index] = !updatedSelected[index];
    state = state.copyWith(selected: updatedSelected);
  }

  void selectAll(bool selectAll) {
    final updatedSelected = List<bool>.filled(state.students.length, selectAll);
    state = state.copyWith(selected: updatedSelected);
  }

  void setStudents(List<String> students) {
    state = state.copyWith(
      students: students,
      selected: List<bool>.filled(students.length, false),
    );
  }

  void deleteSelected() {
    final updatedStudents = <String>[];
    final updatedSelected = <bool>[];

    for (int i = 0; i < state.students.length; i++) {
      if (!state.selected[i]) {
        updatedStudents.add(state.students[i]);
        updatedSelected.add(false);
      }
    }

    state = state.copyWith(
      students: updatedStudents,
      selected: updatedSelected,
      isSelectionMode: false,
    );
  }

  void addStudent(String student) {
    final updatedStudents = [...state.students, student];
    final updatedSelected = [...state.selected, false];
    state = state.copyWith(
      students: updatedStudents,
      selected: updatedSelected,
    );
  }

  void sortStudents({
    required List<String> students,
    required String sortBy,
    required void Function(List<String>) onSorted,
  }) {
    final sortedStudents = [...students]
      ..sort((a, b) {
        final aDetails = a.split('_');
        final bDetails = b.split('_');

        if (sortBy == 'mã số') {
          final aId = int.tryParse(aDetails[0]) ?? 0;
          final bId = int.tryParse(bDetails[0]) ?? 0;
          return aId.compareTo(bId);
        } else {
          final aName = aDetails[1].split(' ').last.toLowerCase();
          final bName = bDetails[1].split(' ').last.toLowerCase();
          return aName.compareTo(bName);
        }
      });
    onSorted(sortedStudents);
  }

  Future<void> importStudentsFromExcel({
    required BuildContext context,
    required List<String> students,
    required List<bool> selected,
    required String test,
    required Function(List<String>) onUpdateStudents,
    required Function(List<bool>) onUpdateSelected,
    required void Function({required String message}) showToast,
  }) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (!context.mounted) return;

    if (result != null) {
      final file = result.files.single.path;
      if (file != null) {
        final bytes = File(file).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);
        List<String> newStudents = [];

        for (var table in excel.tables.keys) {
          var rows = excel.tables[table]!.rows;

          if (rows.isNotEmpty) {
            String idHeader = rows[0][0]?.value?.toString() ?? '';
            String nameHeader = rows[0][1]?.value?.toString() ?? '';

            if (!(idHeader == 'Mã số' || nameHeader == 'Tên')) {
              showToast(message: 'Tệp Excel phải có tiêu đề "Mã số" và "Tên"');
              return;
            }

            for (int rowIndex = 1; rowIndex < rows.length; rowIndex++) {
              var row = rows[rowIndex];
              if (row.length >= 2) {
                String id = row[0]?.value?.toString() ?? '';
                String name = row[1]?.value?.toString() ?? '';

                bool idExists = students.any((student) {
                  List<String> studentDetails = student.split('_');
                  return studentDetails[0] == id;
                });

                if (!idExists) {
                  newStudents.add('${id}_$name');
                } else {
                  showToast(
                    message:
                        'Học sinh có mã số "$id" đã tồn tại và sẽ bị bỏ qua.',
                  );
                }
              }
            }
          }
        }

        students.addAll(newStudents);
        selected.addAll(List<bool>.filled(newStudents.length, false));

        await saveStudents(test, students);

        if (!context.mounted) return;

        onUpdateStudents(students);
        onUpdateSelected(selected);

        if (!context.mounted) return;

        Navigator.of(context).pop();
        showToast(message: 'Nhập danh sách học sinh thành công');
      }
    }
  }

  Future<void> saveStudents(String test, List<String> students) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('students_$test', students);
  }
}

class StudentListState {
  final List<String> students;
  final List<bool> selected;
  final bool isSelectionMode;

  StudentListState({
    this.students = const [],
    this.selected = const [],
    this.isSelectionMode = false,
  });

  StudentListState copyWith({
    List<String>? students,
    List<bool>? selected,
    bool? isSelectionMode,
  }) {
    return StudentListState(
      students: students ?? this.students,
      selected: selected ?? this.selected,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

final studentListControllerProvider =
    StateNotifierProvider<StudentListController, StudentListState>(
      (ref) => StudentListController(),
    );
