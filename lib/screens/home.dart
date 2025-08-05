// lib/screens/home.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_management_app/providers/student_user.dart';

import '../models/student_test.dart';
import '../providers/student_test_provider.dart';
import '../widgets/form_text_field.dart';
import '../widgets/toast.dart';
import 'menu_test.dart';
import '../providers/teacher_user.dart';
import 'test_taking.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    refreshNotifier.dispose();
    super.dispose();
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          _buildDrawerListTile(
            icon: Icons.info_outline,
            title: 'Giới thiệu',
            onTap: () {},
          ),
          _buildDrawerListTile(
            icon: Icons.help_outline,
            title: 'Hướng dẫn',
            onTap: () {},
          ),
          _buildDrawerListTile(
            icon: Icons.exit_to_app,
            title: 'Đăng xuất',
            textColor: Colors.red,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset('assets/images/Logo.png', fit: BoxFit.cover),
        ),
      ),
      accountName: const Text(
        'Ứng dụng quản lý bài kiểm tra',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      accountEmail: const Text(
        'toanpham622002@gmail.com',
        style: TextStyle(color: Colors.black, fontSize: 16),
      ),
    );
  }

  Widget _buildDrawerListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
    );
  }

  Future<String> getTestStatus(String testId) async {
    final prefs = await SharedPreferences.getInstance();

    bool submitted = prefs.getBool('test_submitted_$testId') ?? false;
    if (submitted) {
      return 'submitted';
    }

    bool hasStartTime = prefs.containsKey('test_start_time-$testId');

    if (hasStartTime) {
      return 'doing';
    }

    return 'not_done_yet';
  }

  void refreshTestStatus() {
    refreshNotifier.value++;
  }

  Widget _buildTeacherTab() {
    final ref = this.ref;
    final tests = ref.watch(teacherUserProvider);
    final isSelectionMode = ref.watch(selectionModeProvider);
    final selectedItems = ref.watch(selectedItemsProvider);

    // Đảm bảo selectedItems có đúng độ dài
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedItems.length != tests.length) {
        ref.read(selectedItemsProvider.notifier).initialize(tests.length);
      }
    });

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: tests.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có bài kiểm tra nào.\nHãy tạo bài kiểm tra đầu tiên!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    if (index >= tests.length) return const SizedBox.shrink();

                    final teacherTest = tests[index].split('_');
                    if (teacherTest.length < 6) {
                      return const SizedBox.shrink(); // Skip malformed entries
                    }

                    final subject = teacherTest[0];
                    final clazz = teacherTest[1];
                    final questionCount = teacherTest[2];
                    final duration = teacherTest[3];
                    final createTime = teacherTest[4];
                    final testId = teacherTest[5];

                    // Đảm bảo selectedItems có index hợp lệ
                    final isSelected = index < selectedItems.length
                        ? selectedItems[index]
                        : false;

                    return _buildTeacherTestCard(
                      context,
                      index,
                      isSelected,
                      tests[index],
                      subject,
                      clazz,
                      questionCount,
                      duration,
                      createTime,
                      testId,
                      isSelectionMode,
                    );
                  },
                ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: _buildTeacherAddButton(isSelectionMode),
        ),
      ],
    );
  }

  Widget _buildTeacherTestCard(
    BuildContext context,
    int index,
    bool isSelected,
    String test,
    String subject,
    String clazz,
    String questionCount,
    String duration,
    String createTime,
    String testId,
    bool isSelectionMode,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isSelected ? Colors.teal[100] : null,
      child: InkWell(
        onTap: () {
          if (isSelectionMode) {
            ref.read(selectedItemsProvider.notifier).toggle(index);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MenuTestPage(test: test)),
            );
          }
        },
        onLongPress: () {
          ref.read(selectionModeProvider.notifier).state = true;
          ref.read(selectedItemsProvider.notifier).toggle(index);
        },
        child: ListTile(
          title: Text('Lớp $clazz - $subject'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Số câu: $questionCount | Thời gian: $duration phút\nThời gian tạo: $createTime',
              ),
              Text(
                testId,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: isSelectionMode
              ? Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: Colors.teal,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTeacherAddButton(bool isSelectionMode) {
    return FloatingActionButton(
      onPressed: isSelectionMode
          ? null
          : () {
              ref
                  .read(teacherUserProvider.notifier)
                  .addTestTeacher(context: context, ref: ref);
            },
      backgroundColor: isSelectionMode ? Colors.grey : Colors.teal,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildStudentTab() {
    final isSelectionMode = ref.watch(selectionModeProvider);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer(
            builder: (context, ref, _) {
              final studentTests = ref.watch(studentTestsProvider);
              return ValueListenableBuilder<int>(
                valueListenable: refreshNotifier,
                builder: (context, value, child) {
                  return ListView.builder(
                    itemCount: studentTests.length,
                    itemBuilder: (context, index) {
                      final test = studentTests[index];
                      return FutureBuilder<String>(
                        key: ValueKey('${test.testId}_$value'),
                        future: getTestStatus(test.testId),
                        builder: (context, snapshot) {
                          return _buildStudentTestCard(
                            context,
                            test,
                            snapshot.data ?? 'not_done_yet',
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: _buildStudentDownloadButton(isSelectionMode),
        ),
      ],
    );
  }

  Widget _buildStudentTestCard(
    BuildContext context,
    StudentTest test,
    String status,
  ) {
    Color statusColor;
    String statusText;

    switch (status) {
      case 'submitted':
        statusText = 'Đã nộp';
        statusColor = Colors.green;
        break;
      case 'doing':
        statusText = 'Đang làm';
        statusColor = Colors.orange;
        break;
      default:
        statusText = 'Chưa làm';
        statusColor = Colors.grey;
        break;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _handleStudentTestTap(context, test, status),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lớp ${test.clazz} - ${test.subject}\nMã đề: ${test.code}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Số câu: ${test.questionCount} | Thời gian: ${test.duration} phút',
              ),
              Text(
                test.testId,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  statusText,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStudentTestTap(
    BuildContext context,
    StudentTest test,
    String currentStatus,
  ) async {
    String? studentName;
    String? studentId;

    if (currentStatus == 'not_done_yet') {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return _buildStudentInfoSheet(
            onNameChanged: (value) => studentName = value,
            onIdChanged: (value) => studentId = value,
            onStart: () => Navigator.of(context).pop(true),
          );
        },
      );

      if (result != true ||
          (studentName ?? '').isEmpty ||
          (studentId ?? '').isEmpty) {
        return;
      }
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      studentId = prefs.getString('current_student_id');
      studentName = prefs.getString('current_student_name');
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestTakingPage(
          testId: test.testId,
          subject: test.subject,
          clazz: test.clazz,
          code: test.code,
          questionCount: test.questionCount,
          duration: test.duration,
          imageUrls: test.imageUrls,
          status: currentStatus,
          studentName: studentName,
          studentId: studentId,
          onSubmit: () {
            final tabController = DefaultTabController.of(context);
            tabController.animateTo(1);
          },
        ),
      ),
    );

    refreshTestStatus();
  }

  Widget _buildStudentInfoSheet({
    required Function(String) onNameChanged,
    required Function(String) onIdChanged,
    required VoidCallback onStart,
  }) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: StatefulBuilder(
        builder: (context, setState) {
          final isButtonEnabled =
              nameController.text.isNotEmpty && codeController.text.isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thông tin thí sinh',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FormTextField(
                controller: nameController,
                label: 'Họ và tên',
                hint: 'Nhập họ và tên của bạn',
                onChangedCallback: (newName) {
                  setState(() {});
                  onNameChanged(newName);
                },
              ),
              const SizedBox(height: 16),
              FormTextField(
                controller: codeController,
                label: 'Mã số',
                hint: 'Nhập mã số của bạn',
                onChangedCallback: (newId) {
                  setState(() {});
                  onIdChanged(newId);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isButtonEnabled
                      ? () {
                          onNameChanged(nameController.text);
                          onIdChanged(codeController.text);
                          onStart();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isButtonEnabled
                        ? Colors.green
                        : Colors.grey,
                  ),
                  child: const Text(
                    'Bắt đầu làm bài',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentDownloadButton(bool isSelectionMode) {
    return FloatingActionButton(
      onPressed: isSelectionMode
          ? null
          : () {
              ref
                  .read(studentUserProvider.notifier)
                  .getTest(
                    context: context,
                    showToast: ({required String message}) {
                      showToast(message: message);
                    },
                  );
            },
      backgroundColor: isSelectionMode ? Colors.grey : Colors.teal,
      child: const Icon(Icons.file_download, color: Colors.white),
    );
  }

  AppBar _buildAppBar(
    bool isSelectionMode,
    List<bool> selectedItems,
    List tests,
    WidgetRef ref,
  ) {
    return AppBar(
      backgroundColor: Colors.blueGrey,
      foregroundColor: Colors.white,
      title: const Text('Quản lý bài kiểm tra'),
      centerTitle: true,
      leading: _buildLeading(isSelectionMode, ref),
      actions: _buildActions(isSelectionMode, selectedItems, tests, ref),
      bottom: const TabBar(
        indicatorColor: Colors.green,
        tabs: [
          Tab(
            child: Text(
              'GIÁO VIÊN',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          Tab(
            child: Text(
              'HỌC SINH',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  // Hàm xây dựng leading cho AppBar
  Widget _buildLeading(bool isSelectionMode, WidgetRef ref) {
    return isSelectionMode
        ? IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(selectionModeProvider.notifier).state = false;
              ref.read(selectedItemsProvider.notifier).clear();
            },
          )
        : Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          );
  }

  List<Widget> _buildActions(
    bool isSelectionMode,
    List<bool> selectedItems,
    List tests,
    WidgetRef ref,
  ) {
    if (isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: () {
            final allSelected = selectedItems.every((isSel) => isSel);
            ref.read(selectedItemsProvider.notifier).selectAll(!allSelected);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            ref
                .read(teacherUserProvider.notifier)
                .deleteSelectedTests(selectedItems);
            ref.read(selectionModeProvider.notifier).state = false;
            ref.read(selectedItemsProvider.notifier).clear();
          },
        ),
      ];
    } else {
      return [
        PopupMenuButton<String>(
          onSelected: (String criteria) {
            ref.read(teacherUserProvider.notifier).sortTestsTeacher(criteria);
          },
          icon: Image.asset(
            'assets/icons/sort.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
          itemBuilder: (BuildContext context) {
            return {'lớp', 'môn học', 'ngày tạo'}.map((choice) {
              return PopupMenuItem<String>(
                value: choice,
                child: Text('Sắp xếp theo ${choice[0]}${choice.substring(1)}'),
              );
            }).toList();
          },
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final tests = ref.watch(teacherUserProvider);
    final isSelectionMode = ref.watch(selectionModeProvider);
    final selectedItems = ref.watch(selectedItemsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedItems.length != tests.length) {
        ref.read(selectedItemsProvider.notifier).initialize(tests.length);
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: _buildAppBar(isSelectionMode, selectedItems, tests, ref),
          drawer: _buildDrawer(),
          body: TabBarView(
            physics: isSelectionMode
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            children: [_buildTeacherTab(), _buildStudentTab()],
          ),
        ),
      ),
    );
  }
}
