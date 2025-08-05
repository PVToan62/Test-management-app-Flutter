// lib/screens/add_test_form.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/form_text_field.dart';

class AddTestForm extends StatefulWidget {
  final Function(String, String, String, String, String, String) onSubmit;

  const AddTestForm({super.key, required this.onSubmit});

  @override
  State<AddTestForm> createState() => _AddTestFormState();
}

class _AddTestFormState extends State<AddTestForm> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _questionsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  late final String testId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    testId = _generateRandomCode(6);
  }

  String _generateRandomCode(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _classController.dispose();
    _questionsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  bool get _isValidForm {
    return _subjectController.text.trim().isNotEmpty &&
        _classController.text.trim().isNotEmpty &&
        _questionsController.text.trim().isNotEmpty &&
        _durationController.text.trim().isNotEmpty &&
        !_isSubmitting;
  }

  void _submitForm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final subject = _subjectController.text.trim();
    final clazz = _classController.text.trim();
    final questions = _questionsController.text.trim();
    final duration = _durationController.text.trim();

    if (subject.isEmpty ||
        clazz.isEmpty ||
        questions.isEmpty ||
        duration.isEmpty) {
      throw Exception('Vui lòng điền đầy đủ thông tin');
    }

    final questionsNum = int.tryParse(questions);
    final durationNum = int.tryParse(duration);

    if (questionsNum == null || questionsNum <= 0) {
      throw Exception('Số câu hỏi phải là số nguyên dương');
    }

    if (durationNum == null || durationNum <= 0) {
      throw Exception('Thời gian phải là số nguyên dương');
    }

    final String createTime = DateFormat(
      'HH:mm dd/MM/yyyy',
    ).format(DateTime.now());

    // Gọi callback
    await Future.delayed(Duration.zero);

    widget.onSubmit(subject, clazz, questions, duration, createTime, testId);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Tạo bài kiểm tra',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FormTextField(
              controller: _subjectController,
              label: 'Môn học',
              hint: 'Ví dụ: Toán',
              onChangedCallback: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            FormTextField(
              controller: _classController,
              label: 'Lớp',
              hint: 'Ví dụ: 12A',
              onChangedCallback: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            FormTextField(
              controller: _questionsController,
              label: 'Số câu hỏi',
              hint: 'Ví dụ: 50',
              isNumber: true,
              onChangedCallback: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            FormTextField(
              controller: _durationController,
              label: 'Thời gian (phút)',
              hint: 'Ví dụ: 45',
              isNumber: true,
              onChangedCallback: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.redAccent,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValidForm ? _submitForm : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _isSubmitting
                          ? Colors.grey
                          : Colors.green,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Tạo', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
