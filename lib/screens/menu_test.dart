// lib/screens/menu_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_management_app/providers/teacher_user.dart';

import '../widgets/toast.dart';
import '/providers/menu_test_provider.dart';
import 'create_code.dart';
import 'grade.dart';
import 'student_list.dart';

class MenuTestPage extends ConsumerStatefulWidget {
  final String test;

  const MenuTestPage({super.key, required this.test});

  @override
  ConsumerState<MenuTestPage> createState() => _MenuTestPageState();
}

class _MenuTestPageState extends ConsumerState<MenuTestPage> {
  late String testId;
  late String subject;
  late String clazz;
  late String questions;
  late String duration;
  late String createTime;

  bool isPublished = false;

  @override
  void initState() {
    super.initState();
    List<String> testDetails = widget.test.split('_');
    subject = testDetails[0];
    clazz = testDetails[1];
    questions = testDetails[2];
    duration = testDetails[3];
    createTime = testDetails[4];
    testId = testDetails[5];

    Future.microtask(() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> publishedTests =
          prefs.getStringList('published_tests') ?? [];
      setState(() {
        isPublished = publishedTests.contains(testId);
      });

      ref.read(menuTestProvider.notifier).loadData(widget.test);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        title: const Text('Các chức năng'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildButton(
              icon: Icons.vpn_key,
              text: 'Tạo đáp án',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return CreateCodePage(
                        test: widget.test,
                        numberOfQuestions: int.parse(questions),
                      );
                    },
                  ),
                ).then((_) {
                  ref.read(menuTestProvider.notifier).loadData(widget.test);
                });
              },
            ),
            _buildButton(
              icon: Icons.create,
              text: 'Danh sách chấm điểm',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GradePage(testKey: widget.test),
                  ),
                );
              },
            ),
            _buildButton(
              icon: Icons.list,
              text: 'Danh sách học sinh',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentListPage(test: widget.test),
                  ),
                );
              },
            ),
            _buildButton(
              icon: Icons.assignment,
              text: isPublished ? 'Đã phát bài kiểm tra' : 'Phát bài kiểm tra',
              onPressed: isPublished
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Center(child: Text(testId)),
                            content: const Text(
                              'Gửi mã bài kiểm tra trên cho học sinh để nhận bài kiểm tra',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await ref
                                      .read(teacherUserProvider.notifier)
                                      .publishTest(
                                        context: context,
                                        testId: testId,
                                        testKey: widget.test,
                                        clazz: clazz,
                                        subject: subject,
                                        questions: questions,
                                        duration: duration,
                                        createTime: createTime,
                                        showToast: ({required message}) =>
                                            showToast(message: message),
                                      );

                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();
                                  List<String> publishedTests =
                                      prefs.getStringList('published_tests') ??
                                      [];
                                  if (publishedTests.contains(testId)) {
                                    setState(() {
                                      isPublished = true;
                                    });
                                  }
                                },
                                child: const Text('Phát bài'),
                              ),
                            ],
                          );
                        },
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      width: double.infinity,
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
