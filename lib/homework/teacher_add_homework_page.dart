import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TeacherAddHomeworkPage extends StatefulWidget {
  final Map<String, dynamic>? homeworkToEdit;
  const TeacherAddHomeworkPage({super.key, this.homeworkToEdit});

  @override
  State<TeacherAddHomeworkPage> createState() => _TeacherAddHomeworkPageState();
}

class _TeacherAddHomeworkPageState extends State<TeacherAddHomeworkPage> {
  List classes = [];
  List sections = [];
  int? selectedClassId;
  int? selectedSectionId;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? assignDate;
  DateTime? submissionDate;
  File? selectedFile;

  bool isLoading = false;
  bool _isSubmitting = false; // 🔒 prevent double submit

  @override
  void initState() {
    super.initState();
    assignDate = DateTime.now();
    submissionDate = DateTime.now();

    if (widget.homeworkToEdit != null) {
      _loadEditFlow();
    } else {
      fetchClasses();
    }
  }

  // ============================
  // 🔄 EDIT MODE SEQUENTIAL LOAD
  // ============================
  Future<void> _loadEditFlow() async {
    setState(() => isLoading = true);
    await fetchClasses();
    await fetchHomeworkDetails(widget.homeworkToEdit!['id']);
    if (mounted) setState(() => isLoading = false);
  }

  // ============================
  // 📚 FETCH CLASSES
  // ============================
  Future<void> fetchClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final res = await http.post(
      Uri.parse('https://schoolerp.edusathi.in/api/get_class'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode == 200 && mounted) {
      setState(() {
        classes = jsonDecode(res.body);
      });
    }
  }

  // ============================
  // 📘 FETCH SECTIONS
  // ============================
  Future<void> fetchSections(int classId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final res = await http.post(
      Uri.parse('https://schoolerp.edusathi.in/api/get_section'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'ClassId': classId}),
    );

    if (res.statusCode == 200 && mounted) {
      setState(() {
        sections = jsonDecode(res.body);
        selectedSectionId = null;
      });
    }
  }

  // ============================
  // ✏️ FETCH HOMEWORK DETAILS
  // ============================
  Future<void> fetchHomeworkDetails(int homeworkId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final res = await http.post(
      Uri.parse('https://schoolerp.edusathi.in/api/teacher/homework/edit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'HomeworkId': homeworkId}),
    );

    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body);

    if (!mounted) return;

    _titleController.text = data['HomeworkTitle'] ?? '';
    _descriptionController.text = data['Remark'] ?? '';
    assignDate = DateTime.tryParse(data['WorkDate'] ?? '');
    submissionDate = DateTime.tryParse(data['SubmissionDate'] ?? '');

    selectedClassId = int.tryParse(data['Class'] ?? '');
    if (selectedClassId != null) {
      await fetchSections(selectedClassId!);
    }

    selectedSectionId = int.tryParse(data['Section'] ?? '');
    setState(() {});
  }

  // ============================
  // 📤 SUBMIT / UPDATE HOMEWORK
  // ============================
  Future<void> submitHomework() async {
    if (_isSubmitting) return;

    if (selectedClassId == null ||
        selectedSectionId == null ||
        assignDate == null ||
        submissionDate == null ||
        _titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    _isSubmitting = true;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final isEdit = widget.homeworkToEdit != null;
      final url = isEdit
          ? 'https://schoolerp.edusathi.in/api/teacher/homework/update'
          : 'https://schoolerp.edusathi.in/api/teacher/homework/store';

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['Class'] = selectedClassId.toString()
        ..fields['Section'] = selectedSectionId.toString()
        ..fields['Title'] = _titleController.text.trim()
        ..fields['Description'] = _descriptionController.text.trim()
        ..fields['AssignDate'] = DateFormat('yyyy-MM-dd').format(assignDate!)
        ..fields['SubmissionDate'] = DateFormat(
          'yyyy-MM-dd',
        ).format(submissionDate!);

      if (isEdit) {
        request.fields['HomeworkId'] = widget.homeworkToEdit!['id'].toString();
      }

      if (selectedFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('Attachment', selectedFile!.path),
        );
      }

      final resp = await request.send();
      final body = await resp.stream.bytesToString();
      final decoded = jsonDecode(body);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(decoded['message'] ?? 'Success')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(decoded['message'] ?? 'Failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      _isSubmitting = false;
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method is the same)
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.homeworkToEdit != null ? "Edit Homework" : "Add Homework",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: "Class"),
                    value: selectedClassId,
                    items: classes.map((cls) {
                      return DropdownMenuItem<int>(
                        value: cls['id'],
                        child: Text(cls['Class']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedClassId = val);
                      if (val != null) fetchSections(val);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: "Section"),
                    value: selectedSectionId,
                    items: sections.map((sec) {
                      return DropdownMenuItem<int>(
                        value: sec['id'],
                        child: Text(sec['SectionName']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedSectionId = val),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Homework Title",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: "Description"),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Assign Date",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: assignDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              assignDate = picked;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                assignDate != null
                                    ? DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(assignDate!)
                                    : DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(DateTime.now()),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.deepPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Submission Date",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: submissionDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              submissionDate = picked;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                submissionDate != null
                                    ? DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(submissionDate!)
                                    : DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(DateTime.now()),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.deepPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Attachment (Optional)",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 5),
                      selectedFile == null
                          ? ElevatedButton.icon(
                              icon: const Icon(Icons.attach_file),
                              label: const Text("Choose File"),
                              onPressed: pickFile,
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.deepPurple),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.deepPurple.withOpacity(0.05),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file,
                                    color: Colors.deepPurple,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedFile!.path.split('/').last,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedFile = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      onPressed: submitHomework,
                      child: Text(
                        widget.homeworkToEdit != null
                            ? "Update Homework"
                            : "Submit Homework",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
