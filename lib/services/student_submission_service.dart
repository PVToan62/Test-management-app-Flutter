// lib/services/student_submission_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentSubmissionService {
  static final supabase = Supabase.instance.client;

  static Future<bool> submitStudentAnswers({
    required String testId,
    required String studentId,
    required String studentName,
    required String code,
    required Map<int, String> studentAnswers,
    required void Function({required String message}) showToast,
  }) async {
    try {
      if (testId.isEmpty || studentId.isEmpty || code.isEmpty) {
        showToast(message: 'Thiếu thông tin cần thiết để nộp bài');
        return false;
      }

      Map<String, String> answersFormatted = {};
      studentAnswers.forEach((key, value) {
        answersFormatted[key.toString()] = value;
      });

      print(
        'Submitting for testId: $testId, code: $code, studentId: $studentId',
      );

      List<dynamic> newStudentEntry = [
        studentId,
        studentName,
        answersFormatted,
      ];

      final response = await supabase
          .from('test_management_app')
          .select('students_ans')
          .eq('test_id', testId)
          .eq('codes', code)
          .maybeSingle();

      List<dynamic> currentStudentsAns = [];

      if (response != null) {
        if (response['students_ans'] != null) {
          try {
            currentStudentsAns = List<dynamic>.from(response['students_ans']);
          } catch (e) {
            print('Error parsing students_ans: $e');
            currentStudentsAns = [];
          }
        }
      } else {
        showToast(message: 'Không tìm thấy bài kiểm tra với mã: $code');
        return false;
      }

      print('Current students_ans: $currentStudentsAns');

      bool studentExists = false;
      for (int i = 0; i < currentStudentsAns.length; i++) {
        if (currentStudentsAns[i] is List &&
            currentStudentsAns[i].length > 0 &&
            currentStudentsAns[i][0].toString() == studentId) {
          currentStudentsAns[i] = newStudentEntry;
          studentExists = true;
          print('Updated existing student at index $i');
          break;
        }
      }

      if (!studentExists) {
        currentStudentsAns.add(newStudentEntry);
        print('Added new student entry');
      }

      print('Final students_ans to update: $currentStudentsAns');

      final updateResponse = await supabase
          .from('test_management_app')
          .update({'students_ans': currentStudentsAns})
          .eq('test_id', testId)
          .eq('codes', code)
          .select();

      print('Update response: $updateResponse');

      if (updateResponse.isEmpty) {
        showToast(message: 'Không tìm thấy bài kiểm tra để cập nhật');
        return false;
      }

      showToast(message: 'Nộp bài thành công!');
      return true;
    } on PostgrestException catch (e) {
      print('Supabase error: ${e.message}');
      print('Error code: ${e.code}');
      print('Error details: ${e.details}');
      showToast(message: 'Lỗi database: ${e.message}');
      return false;
    } catch (e) {
      print('General error submitting student answers: $e');
      showToast(message: 'Lỗi không xác định khi nộp bài: $e');
      return false;
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final response = await supabase
          .from('test_management_app')
          .select('test_id')
          .limit(1);
      return true;
    } catch (e) {
      print('Connection check failed: $e');
      return false;
    }
  }

  static Future<void> debugTestData({
    required String testId,
    required String code,
  }) async {
    try {
      print('=== DEBUG TEST DATA ===');
      print('Looking for testId: $testId, code: $code');

      final response = await supabase
          .from('test_management_app')
          .select('*')
          .eq('test_id', testId)
          .eq('codes', code);

      print('Found records: ${response.length}');
      if (response.isNotEmpty) {
        print('Record data: ${response.first}');
        print('Current students_ans: ${response.first['students_ans']}');
      }
      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  static Future<GradingResult?> gradeStudentTest({
    required String testId,
    required String studentId,
    required String code,
    required void Function({required String message}) showToast,
  }) async {
    try {
      final response = await supabase
          .from('test_management_app')
          .select('answers, students_ans')
          .eq('test_id', testId)
          .eq('codes', code)
          .maybeSingle(); // Thay đổi từ single() sang maybeSingle()

      if (response == null) {
        showToast(message: 'Không tìm thấy bài kiểm tra');
        return null;
      }

      Map<String, String> correctAnswers = Map<String, String>.from(
        response['answers'] ?? {},
      );

      List<dynamic> studentsAns = List<dynamic>.from(
        response['students_ans'] ?? [],
      );
      Map<String, String>? studentAnswers;
      String? studentName;

      for (var studentEntry in studentsAns) {
        if (studentEntry is List &&
            studentEntry.length >= 3 &&
            studentEntry[0].toString() == studentId) {
          studentName = studentEntry[1].toString();
          studentAnswers = Map<String, String>.from(studentEntry[2] ?? {});
          break;
        }
      }

      if (studentAnswers == null) {
        showToast(message: 'Không tìm thấy bài làm của học sinh');
        return null;
      }

      int totalQuestions = correctAnswers.length;
      int correctCount = 0;
      Map<String, QuestionResult> details = {};

      correctAnswers.forEach((questionNum, correctAnswer) {
        String studentAnswer = studentAnswers![questionNum] ?? '';

        List<String> studentOptions =
            studentAnswer
                .split(',')
                .map((s) => s.trim().toUpperCase())
                .where((s) => s.isNotEmpty)
                .toList()
              ..sort();

        List<String> correctOptions =
            correctAnswer
                .split(',')
                .map((s) => s.trim().toUpperCase())
                .where((s) => s.isNotEmpty)
                .toList()
              ..sort();

        bool isCorrect = _listEquals(studentOptions, correctOptions);

        if (isCorrect) {
          correctCount++;
        }

        details[questionNum] = QuestionResult(
          questionNumber: int.tryParse(questionNum) ?? 0,
          studentAnswer: studentAnswer,
          correctAnswer: correctAnswer,
          isCorrect: isCorrect,
        );
      });

      double score = totalQuestions > 0
          ? (correctCount / totalQuestions) * 10
          : 0.0;

      GradingResult result = GradingResult(
        studentId: studentId,
        studentName: studentName ?? '',
        testId: testId,
        code: code,
        totalQuestions: totalQuestions,
        correctAnswers: correctCount,
        score: score,
        details: details,
      );

      showToast(
        message: 'Chấm điểm thành công! Điểm: ${score.toStringAsFixed(2)}/10',
      );
      return result;
    } catch (e) {
      print('Error grading student test: $e');
      showToast(message: 'Lỗi khi chấm điểm: $e');
      return null;
    }
  }

  static Future<List<StudentSubmission>> getSubmittedStudents({
    required String testId,
    required String code,
  }) async {
    try {
      final response = await supabase
          .from('test_management_app')
          .select('students_ans')
          .eq('test_id', testId)
          .eq('codes', code)
          .maybeSingle(); // Thay đổi từ single() sang maybeSingle()

      if (response == null || response['students_ans'] == null) {
        return [];
      }

      List<dynamic> studentsAns = List<dynamic>.from(response['students_ans']);
      List<StudentSubmission> submissions = [];

      for (var studentEntry in studentsAns) {
        if (studentEntry is List && studentEntry.length >= 3) {
          submissions.add(
            StudentSubmission(
              studentId: studentEntry[0].toString(),
              studentName: studentEntry[1].toString(),
              testId: testId,
              code: code,
              answers: Map<String, String>.from(studentEntry[2] ?? {}),
            ),
          );
        }
      }

      return submissions;
    } catch (e) {
      print('Error getting submitted students: $e');
      return [];
    }
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<List<String>?> getCodeImageUrl({
    required String testId,
    required String code,
  }) async {
    try {
      final response = await supabase
          .from('test_management_app')
          .select('image_urls')
          .eq('test_id', testId)
          .eq('codes', code)
          .maybeSingle();

      if (response != null && response['image_urls'] != null) {
        return List<String>.from(response['image_urls'] as List);
      }
      return null;
    } catch (e) {
      print('Error getting code image URLs: $e');
      return null;
    }
  }
}

class GradingResult {
  final String studentId;
  final String studentName;
  final String testId;
  final String code;
  final int totalQuestions;
  final int correctAnswers;
  final double score;
  final Map<String, QuestionResult> details;

  GradingResult({
    required this.studentId,
    required this.studentName,
    required this.testId,
    required this.code,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.details,
  });

  double get percentage =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;

  String get grade {
    if (score >= 9.0) return 'A+';
    if (score >= 8.5) return 'A';
    if (score >= 8.0) return 'B+';
    if (score >= 7.0) return 'B';
    if (score >= 6.5) return 'C+';
    if (score >= 5.5) return 'C';
    if (score >= 4.0) return 'D';
    return 'F';
  }
}

class QuestionResult {
  final int questionNumber;
  final String studentAnswer;
  final String correctAnswer;
  final bool isCorrect;

  QuestionResult({
    required this.questionNumber,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.isCorrect,
  });
}

class StudentSubmission {
  final String studentId;
  final String studentName;
  final String testId;
  final String code;
  final Map<String, String> answers;

  StudentSubmission({
    required this.studentId,
    required this.studentName,
    required this.testId,
    required this.code,
    required this.answers,
  });
}
