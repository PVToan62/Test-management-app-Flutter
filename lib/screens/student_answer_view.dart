// lib/screens/student_answer_view.dart

import 'package:flutter/material.dart';

import '../services/student_submission_service.dart';
import 'full_screen_image_viewer.dart';

class StudentAnswerViewPage extends StatefulWidget {
  final GradingResult result;
  final String testId;

  const StudentAnswerViewPage({
    super.key,
    required this.result,
    required this.testId,
  });

  @override
  StudentAnswerViewPageState createState() => StudentAnswerViewPageState();
}

class StudentAnswerViewPageState extends State<StudentAnswerViewPage> {
  List<String> codeImageUrls = [];
  bool isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadCodeImage();
  }

  Future<void> _loadCodeImage() async {
    setState(() {
      isLoadingImage = true;
    });

    final imageUrls = await StudentSubmissionService.getCodeImageUrl(
      testId: widget.testId,
      code: widget.result.code,
    );

    setState(() {
      codeImageUrls = imageUrls ?? [];
      isLoadingImage = false;
    });
  }

  void _showCodeImage() {
    if (codeImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy ảnh mã đề'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageUrls: codeImageUrls),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        title: const Text('Chi tiết bài làm'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: isLoadingImage ? null : _showCodeImage,
            icon: isLoadingImage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.image),
            tooltip: 'Xem ảnh mã đề',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã số: ${widget.result.studentId}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Họ và tên: ${widget.result.studentName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã đề: ${widget.result.code}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(widget.result.score),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Điểm: ${widget.result.score.toStringAsFixed(1)}/10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Đúng: ${widget.result.correctAnswers}/${widget.result.totalQuestions} câu',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.result.details.length,
              itemBuilder: (context, index) {
                String questionNum = widget.result.details.keys.elementAt(
                  index,
                );
                QuestionResult questionResult =
                    widget.result.details[questionNum]!;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 1,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: questionResult.isCorrect
                            ? Colors.green
                            : Colors.red,
                        width: 2,
                      ),
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: questionResult.isCorrect
                                ? Colors.green
                                : Colors.red,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                questionResult.isCorrect
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: questionResult.isCorrect
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Câu: $questionNum',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            children: ['A', 'B', 'C', 'D', 'E', 'F'].map((
                              option,
                            ) {
                              bool isStudentAnswer = questionResult
                                  .studentAnswer
                                  .split(',')
                                  .contains(option);
                              bool isCorrectAnswer = questionResult
                                  .correctAnswer
                                  .split(',')
                                  .contains(option);
                              Color checkboxColor;
                              if (isStudentAnswer && isCorrectAnswer) {
                                checkboxColor = Colors.green;
                              } else if (isStudentAnswer && !isCorrectAnswer) {
                                checkboxColor = Colors.red;
                              } else if (!isStudentAnswer && isCorrectAnswer) {
                                checkboxColor = Colors.green;
                              } else {
                                checkboxColor = Colors.grey;
                              }
                              return Container(
                                margin: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: isCorrectAnswer
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isCorrectAnswer
                                            ? Colors.green[700]
                                            : Colors.black,
                                      ),
                                    ),
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        checkboxTheme: CheckboxThemeData(
                                          fillColor: WidgetStateProperty.all(
                                            checkboxColor,
                                          ),
                                        ),
                                      ),
                                      child: Checkbox(
                                        value: isStudentAnswer,
                                        onChanged: null,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (questionResult.studentAnswer.isEmpty ||
                            !questionResult.isCorrect)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (questionResult.studentAnswer.isEmpty)
                                  const Text(
                                    'Học sinh chưa chọn đáp án',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  Text(
                                    'Đáp án đúng: ${questionResult.correctAnswer}',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 6.5) return Colors.blue;
    if (score >= 5.0) return Colors.orange;
    return Colors.red;
  }
}
