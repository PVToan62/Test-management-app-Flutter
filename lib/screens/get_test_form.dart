// lib/screens/get_test_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/form_text_field.dart';

class GetTestForm extends ConsumerStatefulWidget {
  final Future<String?> Function(String) onSubmit;
  final List<String> existingTestIds;

  const GetTestForm({
    super.key,
    required this.onSubmit,
    required this.existingTestIds,
  });

  @override
  ConsumerState<GetTestForm> createState() => _GetTestFormState();
}

class _GetTestFormState extends ConsumerState<GetTestForm> {
  final TextEditingController _testIdController = TextEditingController();
  String? _errorText;
  bool _showError = false;

  @override
  void dispose() {
    _testIdController.dispose();
    super.dispose();
  }

  void _validateForm() {
    String testId = _testIdController.text.trim();
    bool isExist = widget.existingTestIds.any((existingId) => existingId == testId);

    if (isExist) {
      _errorText = 'Bài kiểm tra đã tồn tại!';
    } else {
      _errorText = null;
    }
  }

  void _onSubmitted() async {
    _validateForm();
    setState(() {
      _showError = true;
    });

    if (_errorText == null) {
      final String? remoteError = await widget.onSubmit(_testIdController.text.trim());

      setState(() {
        if (remoteError != null) {
          _errorText = remoteError;
          _showError = true;
        } else {
          Navigator.pop(context);
        }
      });
    }
  }

  void _onChanged(String text) {
    setState(() {
      _showError = false;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonEnabled = _testIdController.text.trim().length == 6;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Nhận bài kiểm tra',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FormTextField(
              controller: _testIdController,
              label: 'Mã bài kiểm tra',
              hint: 'Nhập mã gồm 6 ký tự',
              onChangedCallback: _onChanged,
              errorText: _showError ? _errorText : null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isButtonEnabled ? _onSubmitted : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text('Nhận', style: TextStyle(fontSize: 16)),
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