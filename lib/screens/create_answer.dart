// lib/screens/create_answer_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_management_app/screens/create_code.dart';
import '../widgets/toast.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CreateAnswerPage extends StatefulWidget {
  final String test;
  final String code;
  final int numberOfQuestions;
  final Map<String, Map<String, String>> answers;

  const CreateAnswerPage({
    super.key,
    required this.test,
    required this.code,
    required this.numberOfQuestions,
    required this.answers,
  });

  @override
  CreateAnswerPageState createState() => CreateAnswerPageState();
}

class CreateAnswerPageState extends State<CreateAnswerPage> {
  Map<int, String> answers = {};
  bool isModified = false;
  bool isShowingImage = false;
  List<File> answerImages = [];

  @override
  void initState() {
    super.initState();
    _initializeAnswers();
    _initializeImages();
  }

  void _initializeAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<int, String> initializedAnswers = {};
    for (int i = 1; i <= widget.numberOfQuestions; i++) {
      String key = '${widget.test}_${widget.code}_answer_$i';
      String? savedAnswer = prefs.getString(key);
      initializedAnswers[i] =
          savedAnswer ?? widget.answers[widget.code]?[i.toString()] ?? '';
    }
    setState(() {
      answers = initializedAnswers;
    });
  }

  void _initializeImages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> paths =
        prefs.getStringList('${widget.test}_${widget.code}_images') ?? [];
    setState(() {
      answerImages = paths.map((path) => File(path)).toList();
    });
  }

  Future<void> _saveAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (int questionNumber in answers.keys) {
      String key = '${widget.test}_${widget.code}_answer_$questionNumber';
      String answer = answers[questionNumber] ?? '';

      if (answer.trim().isNotEmpty) {
        await prefs.setString(key, answer);
      } else {
        await prefs.remove(key);
      }
    }
    showToast(message: 'Đáp án cho mã đề ${widget.code} đã được lưu!');
    setState(() {
      isModified = false;
    });
  }

  Future<void> _updateGlobalAnswers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? existing = prefs.getString('answers_${widget.test}');
    Map<String, Map<String, String>> allAnswers = {};
    if (existing != null) {
      allAnswers = Map<String, Map<String, String>>.from(
        jsonDecode(
          existing,
        ).map((k, v) => MapEntry(k, Map<String, String>.from(v))),
      );
    }

    allAnswers[widget.code] = answers.map((k, v) => MapEntry(k.toString(), v));

    await prefs.setString('answers_${widget.test}', jsonEncode(allAnswers));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(picked.path);
      final savedImage = await File(
        picked.path,
      ).copy('${appDir.path}/$fileName');

      setState(() {
        answerImages.add(savedImage);
        isModified = true;
      });
    }
  }

  Future<void> _saveImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> imagePaths = answerImages.map((file) => file.path).toList();
    await prefs.setStringList(
      '${widget.test}_${widget.code}_images',
      imagePaths,
    );
  }

  void _handlePop() async {
    if (isModified) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Chưa lưu thay đổi'),
            content: const Text('Bạn có muốn lưu thay đổi trước khi rời đi?'),
            actions: <Widget>[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _saveAnswers();
                    _updateGlobalAnswers();
                    _saveImage();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Lưu'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Không lưu'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hủy bỏ'),
                ),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isModified,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          title: const Text('Nhập đáp án', style: TextStyle(fontSize: 30)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(isShowingImage ? Icons.create : Icons.image),
              onPressed: () {
                setState(() {
                  isShowingImage = !isShowingImage;
                });
              },
            ),
            IconButton(
              icon: Icon(isShowingImage ? Icons.upload_file : Icons.save),
              onPressed: () {
                if (isShowingImage) {
                  _pickImage();
                } else {
                  _saveAnswers();
                  _updateGlobalAnswers();
                  _saveImage();
                }
              },
            ),
          ],
        ),
        body: isShowingImage
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: answerImages.isEmpty
                    ? const Center(child: Text('Chưa có ảnh đáp án'))
                    : GridView.builder(
                        itemCount: answerImages.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Image.file(
                                answerImages[index],
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      answerImages.removeAt(index);
                                      isModified = true;
                                    });
                                  },
                                  child: Container(
                                    color: Colors.black54,
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.numberOfQuestions,
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
                                  color: const Color(0x80808080),
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
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          option,
                                          style: const TextStyle(
                                            fontSize: 18.0,
                                          ),
                                        ),
                                        Checkbox(
                                          value: (answers[questionNumber] ?? '')
                                              .split(',')
                                              .contains(option),
                                          onChanged: (bool? selected) {
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
                ],
              ),
      ),
    );
  }
}
