// lib/models/student_test.dart

import 'dart:convert';

class StudentTest {
  final String clazz;
  final String subject;
  final String code;
  final String questionCount;
  final String duration;
  final String testId;
  final List<String> imageUrls;

  StudentTest({
    required this.clazz,
    required this.subject,
    required this.code,
    required this.questionCount,
    required this.duration,
    required this.testId,
    required this.imageUrls,
  });

  factory StudentTest.fromMap(Map<String, dynamic> map) {
    return StudentTest(
      clazz: map['clazz'] ?? '',
      subject: map['subject'] ?? '',
      code: map['code'] ?? '',
      questionCount: map['questionCount'] ?? '',
      duration: map['duration'] ?? '',
      testId: map['testId'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clazz': clazz,
      'subject': subject,
      'code': code,
      'questionCount': questionCount,
      'duration': duration,
      'testId': testId,
      'imageUrls': imageUrls,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory StudentTest.fromJson(String source) =>
      StudentTest.fromMap(jsonDecode(source));
}
