// lib/screens/test_taking.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_management_app/widgets/toast.dart';

import '../services/student_submission_service.dart';
import '../utils/dialog_utils.dart';
import 'full_screen_image_viewer.dart';

class TestTakingPage extends StatefulWidget {
  final String testId;
  final String subject;
  final String clazz;
  final String code;
  final String questionCount;
  final String duration;
  final List<String> imageUrls;
  final String status;
  final String? studentId;
  final String? studentName;
  final VoidCallback onSubmit;

  const TestTakingPage({
    super.key,
    required this.testId,
    required this.subject,
    required this.clazz,
    required this.code,
    required this.questionCount,
    required this.duration,
    required this.imageUrls,
    required this.status,
    required this.studentId,
    required this.studentName,
    required this.onSubmit,
  });

  @override
  TestTakingPageState createState() => TestTakingPageState();
}

class TestTakingPageState extends State<TestTakingPage> {
  Map<int, String> answers = {};
  bool isModified = false;
  Timer? _timer;
  int remainingSeconds = 0;
  late String testStatus;

  bool isSubmitting = false;

  static const String answersKeyPrefix = 'test_answers_';

  @override
  void initState() {
    super.initState();
    int totalQuestions = int.tryParse(widget.questionCount) ?? 0;
    for (int i = 1; i <= totalQuestions; i++) {
      answers[i] = '';
    }

    testStatus = widget.status;

    checkSubmissionStatus();
  }

  Future<void> checkSubmissionStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool submitted = prefs.getBool('test_submitted_${widget.testId}') ?? false;

    if (submitted) {
      setState(() {
        testStatus = 'submitted';
      });
      await loadSavedAnswers();
    } else {
      await loadSavedAnswers();
      await initializeTimer();
    }
  }

  Future<void> loadSavedAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedAnswers = prefs.getString('test_answers_${widget.testId}');

    if (savedAnswers != null && savedAnswers.isNotEmpty) {
      Map<String, String> savedMap = {};

      savedAnswers.split(';').where((e) => e.isNotEmpty).forEach((entry) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          savedMap[parts[0]] = parts[1];
        }
      });

      setState(() {
        savedMap.forEach((key, value) {
          int questionNum = int.tryParse(key) ?? 0;
          if (questionNum > 0) {
            answers[questionNum] = value;
          }
        });
      });
    }
  }

  Future<void> initializeAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedAnswersJson = prefs.getString(
      '$answersKeyPrefix${widget.testId}',
    );

    int totalQuestions = int.tryParse(widget.questionCount) ?? 0;

    if (savedAnswersJson != null) {
      Map<String, dynamic> decoded = jsonDecode(savedAnswersJson);
      setState(() {
        answers = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as String),
        );
      });
    } else {
      for (int i = 1; i <= totalQuestions; i++) {
        answers[i] = '';
      }
    }
  }

  Future<void> saveAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$answersKeyPrefix${widget.testId}',
      jsonEncode(answers.map((key, value) => MapEntry(key.toString(), value))),
    );
  }

  Future<void> saveCurrentAnswers() async {
    if (testStatus != 'submitted') {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String answerString = answers.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => '${e.key}:${e.value}')
          .join(';');

      await prefs.setString('test_answers_${widget.testId}', answerString);
    }
  }

  Future<void> initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? startTimestamp = prefs.getInt('test_start_time-${widget.testId}');

    int durationInMinutes = int.tryParse(widget.duration) ?? 0;
    int totalDurationSeconds = durationInMinutes * 60;

    if (startTimestamp == null) {
      int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await prefs.setInt('test_start_time-${widget.testId}', now);
      remainingSeconds = totalDurationSeconds;

      setState(() {
        testStatus = 'doing';
      });
    } else {
      int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int elapsed = now - startTimestamp;
      remainingSeconds = totalDurationSeconds - elapsed;

      if (remainingSeconds < 0) {
        remainingSeconds = 0;
        submitTest();
        return;
      }

      setState(() {
        testStatus = 'doing';
      });
    }

    if (remainingSeconds > 0) {
      startTimer();
    }
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        timer.cancel();
        submitTest();
      } else {
        setState(() {
          remainingSeconds--;
        });
      }
    });
  }

  String formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void submitTest() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    _timer?.cancel();

    showLoadingDialog();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? studentId = widget.studentId;
    String? studentName = widget.studentName;

    bool connectionOk = await StudentSubmissionService.checkConnection();
    if (!connectionOk) {
      showToast(message: 'Không thể kết nối đến server');
      setState(() {
        isSubmitting = false;
      });
      return;
    }

    await StudentSubmissionService.debugTestData(
      testId: widget.testId,
      code: widget.code,
    );

    prefs.remove('test_start_time-${widget.testId}');

    String answerString = answers.entries
        .map((e) => '${e.key}:${e.value}')
        .join(';');

    await prefs.setString('test_answers_${widget.testId}', answerString);
    await prefs.setBool('test_submitted_${widget.testId}', true);

    setState(() {
      testStatus = 'submitted';
    });

    if (studentId != null &&
        studentName != null &&
        studentId.isNotEmpty &&
        studentName.isNotEmpty) {
      bool uploadSuccess = await StudentSubmissionService.submitStudentAnswers(
        testId: widget.testId,
        studentId: studentId,
        studentName: studentName,
        code: widget.code,
        studentAnswers: answers,
        showToast: ({required String message}) => showToast(message: message),
      );

      if (uploadSuccess) {
        hideLoadingDialog();
        showToast(message: 'Nộp bài thành công!');
      } else {
        showToast(message: 'Bài làm đã được lưu local, sẽ thử tải lên sau');
      }
    } else {
      showToast(message: 'Nộp bài thành công (chưa có thông tin học sinh)');
    }

    setState(() {
      isSubmitting = false;
    });

    await Future.delayed(Duration(seconds: 2));
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    int numberOfQuestions = int.tryParse(widget.questionCount) ?? 0;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          if (testStatus != 'submitted') {
            await saveCurrentAnswers();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          title: testStatus == 'submitted'
              ? const Text('Bài làm đã nộp', style: TextStyle(fontSize: 24))
              : Text(
                  'Thời gian: ${formatTime(remainingSeconds)}',
                  style: const TextStyle(fontSize: 24),
                ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (testStatus != 'submitted') {
                await saveCurrentAnswers();
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: () {
                if (widget.imageUrls.isEmpty) {
                  showToast(message: 'Không có hình ảnh nào');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(
                      imageUrls: widget.imageUrls,
                      initialIndex: 0,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: numberOfQuestions,
                itemBuilder: (context, index) {
                  int questionNumber = index + 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 1,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey,
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Câu: $questionNumber',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Wrap(
                            children: ['A', 'B', 'C', 'D', 'E', 'F'].map((
                              option,
                            ) {
                              bool isChecked = (answers[questionNumber] ?? '')
                                  .split(',')
                                  .contains(option);

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    option,
                                    style: const TextStyle(fontSize: 18.0),
                                  ),
                                  Checkbox(
                                    value: isChecked,
                                    onChanged: testStatus == 'submitted'
                                        ? null
                                        : (bool? selected) async {
                                            setState(() {
                                              List<String> selectedAnswers =
                                                  answers[questionNumber]!
                                                      .split(',')
                                                      .where(
                                                        (s) =>
                                                            s.trim().isNotEmpty,
                                                      )
                                                      .toList();

                                              if (selected == true) {
                                                if (!selectedAnswers.contains(
                                                  option,
                                                )) {
                                                  selectedAnswers.add(option);
                                                }
                                              } else {
                                                selectedAnswers.remove(option);
                                              }

                                              answers[questionNumber] =
                                                  selectedAnswers.join(',');
                                              isModified = true;
                                            });

                                            await saveCurrentAnswers();
                                          },
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (testStatus != 'submitted')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (BuildContext context) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Xác nhận nộp bài?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Bạn chắc chắn muốn nộp bài kiểm tra? Sau khi nộp sẽ không thể chỉnh sửa câu trả lời.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text(
                                          'Huỷ',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          submitTest();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Text(
                                          'Nộp bài',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      'Nộp bài',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
