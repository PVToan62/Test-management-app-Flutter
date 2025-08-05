// lib/screens/grade.dart

import 'package:flutter/material.dart';
import '../services/student_submission_service.dart';
import 'student_answer_view.dart';

enum SortType { studentId, studentName, code, score }

class GradePage extends StatefulWidget {
  final String testKey;

  const GradePage({super.key, required this.testKey});

  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends State<GradePage> {
  List<StudentSubmission> submissions = [];
  List<String> availableCodes = [];
  String? selectedCode;
  bool isLoading = false;
  Map<String, GradingResult?> gradingResults = {};
  String? selectedCodeImageUrl;

  SortType currentSortType = SortType.studentId;
  bool isAscending = true;

  late String testId;

  @override
  void initState() {
    super.initState();
    List<String> parts = widget.testKey.split('_');
    testId = parts.length >= 6 ? parts[5] : '';
    _loadAvailableCodes();
  }

  Future<void> _loadAvailableCodes() async {
    setState(() {
      isLoading = true;
    });

    final response = await StudentSubmissionService.supabase
        .from('test_management_app')
        .select('codes')
        .eq('test_id', testId);

    Set<String> codesSet = {};
    for (var item in response) {
      String code = item['codes']?.toString() ?? '';
      if (code.isNotEmpty) {
        codesSet.add(code);
      }
    }

    setState(() {
      availableCodes = codesSet.toList()..sort();
      isLoading = false;
    });

    if (availableCodes.isNotEmpty) {
      await _loadAllSubmissions();
    }
  }

  Future<void> _loadAllSubmissions() async {
    setState(() {
      isLoading = true;
    });

    List<StudentSubmission> allSubmissions = [];

    for (String code in availableCodes) {
      final submissionList =
          await StudentSubmissionService.getSubmittedStudents(
            testId: testId,
            code: code,
          );
      allSubmissions.addAll(submissionList);
    }

    setState(() {
      submissions = allSubmissions;
    });

    await _autoGradeAllStudents(allSubmissions);
    _sortSubmissions();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _autoGradeAllStudents(
    List<StudentSubmission> submissionList,
  ) async {
    for (StudentSubmission submission in submissionList) {
      GradingResult? result = await StudentSubmissionService.gradeStudentTest(
        testId: testId,
        studentId: submission.studentId,
        code: submission.code,
        showToast: ({required String message}) {},
      );

      if (result != null) {
        String studentKey = '${submission.studentId}_${submission.code}';
        setState(() {
          gradingResults[studentKey] = result;
        });
      }
    }
  }

  String _getLastName(String fullName) {
    List<String> nameParts = fullName.trim().split(' ');
    return nameParts.isNotEmpty ? nameParts.last : '';
  }

  void _sortSubmissions() {
    submissions.sort((a, b) {
      int result = 0;

      switch (currentSortType) {
        case SortType.studentId:
          result = a.studentId.compareTo(b.studentId);
          break;
        case SortType.studentName:
          String lastNameA = _getLastName(a.studentName);
          String lastNameB = _getLastName(b.studentName);
          result = lastNameA.compareTo(lastNameB);
          if (result == 0) {
            result = a.studentName.compareTo(b.studentName);
          }
          break;
        case SortType.code:
          result = a.code.compareTo(b.code);
          break;
        case SortType.score:
          String keyA = '${a.studentId}_${a.code}';
          String keyB = '${b.studentId}_${b.code}';
          GradingResult? resultA = gradingResults[keyA];
          GradingResult? resultB = gradingResults[keyB];

          if (resultA == null && resultB == null) {
            result = 0;
          } else if (resultA == null) {
            result = 1;
          } else if (resultB == null) {
            result = -1;
          } else {
            result = resultA.score.compareTo(resultB.score);
          }
          break;
      }

      return isAscending ? result : -result;
    });
  }

  void _onColumnHeaderTap(SortType sortType) {
    setState(() {
      if (currentSortType == sortType) {
        isAscending = !isAscending;
      } else {
        currentSortType = sortType;
        isAscending = true;
      }
    });
    _sortSubmissions();
  }

  Widget _buildSortableColumnHeader(String title, SortType sortType) {
    bool isCurrentSort = currentSortType == sortType;

    return InkWell(
      onTap: () => _onColumnHeaderTap(sortType),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentSort ? Colors.blue : Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            if (isCurrentSort)
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: Colors.blue,
              )
            else
              const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        title: const Text('Danh sách chấm điểm'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllSubmissions,
            tooltip: 'Làm mới và chấm lại',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang cập nhật điểm...'),
                      ],
                    ),
                  )
                : submissions.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có học sinh nào nộp bài',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : _buildStudentTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnSpacing: 20,
          columns: [
            DataColumn(
              label: _buildSortableColumnHeader('Mã số', SortType.studentId),
            ),
            DataColumn(
              label: _buildSortableColumnHeader(
                'Họ và tên',
                SortType.studentName,
              ),
            ),
            DataColumn(
              label: _buildSortableColumnHeader('Mã đề', SortType.code),
            ),
            DataColumn(
              label: _buildSortableColumnHeader('Điểm', SortType.score),
            ),
            const DataColumn(
              label: Text(
                'Xem bài làm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: submissions.map((submission) {
            String studentKey = '${submission.studentId}_${submission.code}';
            GradingResult? result = gradingResults[studentKey];

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    submission.studentId,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      submission.studentName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    submission.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  result != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(result.score),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${result.score.toStringAsFixed(1)}/10',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const Text(
                          'Chưa chấm',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
                DataCell(
                  result != null
                      ? IconButton(
                          onPressed: () => _showDetailedAnswers(result, testId),
                          icon: const Icon(Icons.visibility),
                          tooltip: 'Xem bài làm chi tiết',
                        )
                      : const Text(
                          'Đang chấm...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 6.5) return Colors.blue;
    if (score >= 5.0) return Colors.orange;
    return Colors.red;
  }

  void _showDetailedAnswers(GradingResult result, String testId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudentAnswerViewPage(result: result, testId: testId),
      ),
    );
  }
}
