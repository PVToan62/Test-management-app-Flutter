// lib/screens/create_code.dart

import 'dart:io';
import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/toast.dart';
import 'create_answer.dart';
import '../widgets/form_text_field.dart';

class CreateCodePage extends StatefulWidget {
  final String test;
  final int numberOfQuestions;

  const CreateCodePage({
    super.key,
    required this.test,
    required this.numberOfQuestions,
  });

  @override
  CreateCodePageState createState() => CreateCodePageState();
}

class CreateCodePageState extends State<CreateCodePage> {
  List<String> codes = [];
  bool isSelectionMode = false;
  List<bool> selected = [];
  Map<String, Map<String, String>> answers = {};

  @override
  void initState() {
    super.initState();
    _loadCode();
    _loadAnswers();
  }

  Future<void> _loadCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedCode = prefs.getStringList('codes_${widget.test}');
    if (savedCode != null) {
      setState(() {
        codes = savedCode;
        selected = List<bool>.generate(codes.length, (index) => false);
      });
    }
  }

  Future<void> _saveCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('codes_${widget.test}', codes);
  }

  void _addCode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: AddCodeForm(
            existingCodes: codes,
            onSubmit: (String code) {
              setState(() {
                codes.add(code);
              });
              _saveCode();
              Navigator.pop(context);
              showToast(message: 'Đã thêm mã đề thành công!');
              _loadCode();
            },
          ),
        );
      },
    );
  }

  List<String> sortCodes(List<String> codes) {
    final sortedCodes = List<String>.from(codes);
    sortedCodes.sort((a, b) => a.compareTo(b));
    return sortedCodes;
  }

  void _sortCodes() {
    setState(() {
      codes = sortCodes(codes);
    });
    _saveCode();
  }

  Future<void> deleteAnswersForCode(String code) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final prefix = '${widget.test}_$code';

    for (String key in keys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
    setState(() {
      answers.remove(code);
    });
  }

  void _deleteSelectedCode() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Xác nhận xóa!'),
          content: Text('Bạn có chắc chắn muốn xóa các mã đề đã chọn không?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                List<String> codesToDelete = [];
                List<String> codesToKeep = [];

                for (int i = 0; i < codes.length; i++) {
                  if (selected[i]) {
                    codesToDelete.add(codes[i].split('_')[0]);
                  } else {
                    codesToKeep.add(codes[i]);
                  }
                }

                await Future.wait(
                  codesToDelete.map((code) async {
                    await deleteAnswersForCode(code);
                  }),
                );

                if (!mounted) return;

                setState(() {
                  codes = codesToKeep;
                  selected = List<bool>.filled(codes.length, false);
                  isSelectionMode = false;
                });

                _saveCode();
                Navigator.of(context).pop();
                showToast(message: 'Đã xóa mã đề và đáp án thành công');
              },
              child: Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = 'answers_${widget.test}';
    String answersJson = jsonEncode(answers);
    await prefs.setString(key, answersJson);
  }

  Future<void> _loadAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = 'answers_${widget.test}';
    String? answersJson = prefs.getString(key);
    if (answersJson != null) {
      setState(() {
        answers = Map<String, Map<String, String>>.from(
          jsonDecode(
            answersJson,
          ).map((key, value) => MapEntry(key, Map<String, String>.from(value))),
        );
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      bool allSelected = selected.every((isSelected) => isSelected);
      selected = List<bool>.filled(codes.length, !allSelected);
    });
  }

  void _showImportConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Lưu ý!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/structure_of_the_excel_file_addStudent.png',
              ),
              SizedBox(height: 10),
              Text(
                'Hãy đảm bảo rằng tệp Excel của bạn có cấu trúc đúng với tiêu đề "Mã đề", "Câu" và "Đáp án".',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                _importCodesFromExcel();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCodesFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (!mounted) return;
    if (result != null) {
      final file = result.files.single.path;
      if (file != null) {
        final bytes = File(file).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);
        List<String> newCodes = [];
        Map<String, Map<String, String>> importedAnswers = {};
        for (var table in excel.tables.keys) {
          var rows = excel.tables[table]!.rows;
          if (rows.isNotEmpty) {
            String codeHeader = rows[0][0]?.value?.toString() ?? '';
            String questionHeader = rows[0][1]?.value?.toString() ?? '';
            String answerHeader = rows[0][2]?.value?.toString() ?? '';
            if (!(codeHeader == 'Mã đề' &&
                questionHeader == 'Câu' &&
                answerHeader == 'Đáp án')) {
              showToast(
                message:
                'Tệp Excel phải có tiêu đề "Mã đề", "Câu" và "Đáp án".',
              );
              return;
            }
            for (int rowIndex = 1; rowIndex < rows.length; rowIndex++) {
              var row = rows[rowIndex];
              if (row.length >= 3) {
                String code = row[0]?.value?.toString() ?? '';
                String question = row[1]?.value?.toString() ?? '';
                String answer = row[2]?.value?.toString() ?? '';
                if (codes.any(
                      (existingCode) => existingCode.startsWith(code),
                )) {
                  continue;
                }
                if (!importedAnswers.containsKey(code)) {
                  importedAnswers[code] = {};
                }
                if (answer.trim().isNotEmpty) {
                  importedAnswers[code]![question] = answer;
                }
                if (!newCodes.any(
                      (existingCode) => existingCode.startsWith(code),
                )) {
                  newCodes.add(code);
                }
              }
            }
          }
        }
        if (!mounted) return;
        setState(() {
          codes.addAll(newCodes);
          for (String code in importedAnswers.keys) {
            if (importedAnswers[code]!.isNotEmpty) {
              answers[code] = importedAnswers[code]!;
            }
          }
          selected = List<bool>.filled(codes.length, false);
        });
        _saveCode();
        _saveAnswers();
        showToast(message: 'Mã đề và đáp án đã được nhập thành công.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blueGrey,
        title: Text(
          isSelectionMode ? 'Chọn mã đề' : 'Tạo đáp án',
          style: TextStyle(fontSize: 30),
        ),
        centerTitle: true,
        leading: isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selected = List<bool>.filled(codes.length, false);
                  });
                },
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
        actions: isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.select_all),
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _deleteSelectedCode,
                ),
              ]
            : [
                IconButton(
                  onPressed: _sortCodes,
                  icon: Image.asset(
                    'assets/icons/sort.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: codes.length,
                itemBuilder: (context, index) {
                  String code = codes[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: selected[index] ? Colors.blue[100] : null,
                    child: ListTile(
                      title: Text('Mã đề: $code'),
                      onTap: () {
                        if (isSelectionMode) {
                          setState(() {
                            selected[index] = !selected[index];
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateAnswerPage(
                                test: widget.test,
                                code: code,
                                numberOfQuestions: widget.numberOfQuestions,
                                answers: answers,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          isSelectionMode = true;
                          selected[index] = true;
                        });
                      },
                      trailing: isSelectionMode
                          ? Icon(
                              selected[index]
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.teal,
                            )
                          : null,
                    ),
                  );
                },
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
                    onPressed: isSelectionMode
                        ? null
                        : () {
                            _addCode();
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal,
                    ),
                    child: const Icon(Icons.add, size: 30),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSelectionMode
                        ? null
                        : () {
                            _showImportConfirmation();
                          },
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

class AddCodeForm extends StatefulWidget {
  final Function(String) onSubmit;
  final List<String> existingCodes;

  const AddCodeForm({
    super.key,
    required this.onSubmit,
    required this.existingCodes,
  });

  @override
  State<AddCodeForm> createState() => _AddCodeFormState();
}

class _AddCodeFormState extends State<AddCodeForm> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;
  bool _showError = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _validateForm() {
    String newCode = _codeController.text.trim();
    bool isExist = widget.existingCodes.any((existingCode) {
      String existingCodePart = existingCode.split('_')[0];
      return newCode == existingCodePart;
    });

    if (isExist) {
      _errorText = 'Mã đề đã tồn tại!';
    } else {
      _errorText = null;
    }
  }

  void _onSubmitted() {
    _validateForm();
    setState(() {
      _showError = true;
    });

    if (_errorText == null) {
      widget.onSubmit(_codeController.text.trim());
    }
  }

  void _onChanged(String text) {
    setState(() {
      if (_showError) {
        _validateForm();
        if (_errorText == null) {
          _showError = false;
        }
      }
    });
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
              'Thêm mã đề',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FormTextField(
              controller: _codeController,
              label: 'Mã đề',
              hint: 'Nhập mã đề',
              onChangedCallback: _onChanged,
              errorText: _showError ? _errorText : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _codeController.text.trim().isEmpty
                        ? null
                        : _onSubmitted,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text('Tạo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
