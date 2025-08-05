// lib/screens/studentList.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/form_text_field.dart';
import '../widgets/toast.dart';
import '../providers/student_provider.dart';

class StudentListPage extends ConsumerWidget {
  final String test;

  StudentListPage({super.key, required this.test});

  void _showImportConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lưu ý!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/structure_of_the_excel_file_addStudent.png',
              ),
              const SizedBox(height: 10),
              const Text(
                'Hãy đảm bảo rằng tệp Excel của bạn có cấu trúc đúng với tiêu đề "Mã số" và "Tên".',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                final controller = ref.read(
                  studentListControllerProvider.notifier,
                );

                controller.importStudentsFromExcel(
                  context: context,
                  students: controller.state.students,
                  selected: controller.state.selected,
                  test: test,
                  onUpdateStudents: (updatedStudents) {
                    controller.setStudents(updatedStudents);
                  },
                  onUpdateSelected: (updatedSelected) {
                    controller.state = controller.state.copyWith(
                      selected: updatedSelected,
                    );
                  },
                  showToast: ({required String message}) {
                    showToast(message: message);
                  },
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAddStudentBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AddStudentForm(
          onSubmit: (id, name) {
            final studentNotifier = ref.read(
              studentListControllerProvider.notifier,
            );
            studentNotifier.addStudent('${id}_$name');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentState = ref.watch(studentListControllerProvider);
    final controller = ref.read(studentListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blueGrey,
        title: Text(
          studentState.isSelectionMode
              ? 'Chọn (${studentState.selected.where((s) => s).length})'
              : 'Số học sinh: ${studentState.students.length}',
          style: const TextStyle(fontSize: 20),
        ),
        centerTitle: true,
        leading: studentState.isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => controller.toggleSelectionMode(false),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        actions: studentState.isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => controller.selectAll(
                    !studentState.selected.every((isSelected) => isSelected),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => controller.deleteSelected(),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  onSelected: (choice) {
                    final controller = ref.read(
                      studentListControllerProvider.notifier,
                    );
                    controller.sortStudents(
                      students: controller.state.students,
                      sortBy: choice,
                      onSorted: (sortedStudents) {
                        controller.setStudents(sortedStudents);
                      },
                    );
                  },
                  icon: Image.asset(
                    'assets/icons/sort.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                  itemBuilder: (BuildContext context) {
                    return {'mã số', 'tên'}.map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(
                          'Sắp xếp theo ${choice[0] + choice.substring(1)}',
                        ),
                      );
                    }).toList();
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(
                    label: Text('Mã số', style: TextStyle(fontSize: 20)),
                  ),
                  DataColumn(
                    label: Text('Tên', style: TextStyle(fontSize: 20)),
                  ),
                ],
                rows: List<DataRow>.generate(studentState.students.length, (
                  index,
                ) {
                  final studentDetails = studentState.students[index].split(
                    '_',
                  );
                  return DataRow(
                    selected:
                        studentState.isSelectionMode &&
                        studentState.selected[index],
                    onSelectChanged: studentState.isSelectionMode
                        ? (isSelected) => controller.toggleSelectStudent(index)
                        : null,
                    cells: [
                      DataCell(
                        GestureDetector(
                          onLongPress: () {
                            controller.toggleSelectionMode(true);
                            controller.toggleSelectStudent(index);
                          },
                          child: Text(
                            studentDetails[0],
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      DataCell(
                        GestureDetector(
                          onLongPress: () {
                            controller.toggleSelectionMode(true);
                            controller.toggleSelectStudent(index);
                          },
                          child: Text(
                            studentDetails.length > 1 ? studentDetails[1] : '',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showAddStudentBottomSheet(context, ref),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal,
                    ),
                    child: const Icon(Icons.person_add, size: 30),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: studentState.isSelectionMode
                        ? null
                        : () => _showImportConfirmation(context, ref),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal,
                    ),
                    child: const Icon(Icons.note_add, size: 30),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddStudentForm extends ConsumerStatefulWidget {
  final Function(String id, String name) onSubmit;

  const AddStudentForm({super.key, required this.onSubmit});

  @override
  ConsumerState<AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends ConsumerState<AddStudentForm> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String? _idErrorText;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _validateId() {
    final students = ref.read(studentListControllerProvider).students;
    final id = _idController.text.trim();
    final isDuplicate = students.any((student) => student.split('_')[0] == id);

    if (isDuplicate) {
      _idErrorText = 'Mã số "$id" đã tồn tại!';
    } else {
      _idErrorText = null;
    }
  }

  void _handleSubmit() {
    setState(() {
      _isSubmitted = true;
    });
    _validateId();

    final id = _idController.text.trim();
    final name = _nameController.text.trim();

    if (id.isNotEmpty && name.isNotEmpty && _idErrorText == null) {
      widget.onSubmit(id, name);
      Navigator.pop(context);
    }
  }

  void _updateButtonState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonEnabled =
        _idController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormTextField(
            controller: _idController,
            label: 'Mã số',
            hint: 'Nhập mã số',
            errorText: _isSubmitted ? _idErrorText : null,
            onChangedCallback: (value) {
              if (_isSubmitted) {
                setState(() {
                  _isSubmitted = false;
                });
              }
              _updateButtonState();
            },
          ),
          const SizedBox(height: 10),
          FormTextField(
            controller: _nameController,
            label: 'Tên',
            hint: 'Nhập tên',
            onChangedCallback: (value) {
              _updateButtonState();
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('Thêm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
