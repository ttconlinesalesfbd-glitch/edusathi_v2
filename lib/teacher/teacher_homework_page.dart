import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:edusathi_v2/auth_helper.dart';
import 'package:edusathi_v2/homework/teacher_add_homework_page.dart';
import 'teacher_homework_detail_page.dart';

class TeacherHomeworkPage extends StatefulWidget {
  const TeacherHomeworkPage({super.key});

  @override
  State<TeacherHomeworkPage> createState() => _TeacherHomeworkPageState();
}

class _TeacherHomeworkPageState extends State<TeacherHomeworkPage> {
  List<Map<String, dynamic>> homeworks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHomeworks();
  }

  // ---------------- FETCH HOMEWORKS ----------------
 Future<void> fetchHomeworks() async {
  setState(() => isLoading = true);

  try {
    final response = await AuthHelper.post(
      context,
      'https://schoolerp.edusathi.in/api/teacher/homework',
    );

    // 🔐 token expired → AuthHelper already logout kara dega
    if (response == null || !mounted) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    debugPrint("🟢 HOMEWORK STATUS: ${response.statusCode}");
    debugPrint("📦 HOMEWORK BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      setState(() {
        if (decoded is List) {
          homeworks = List<Map<String, dynamic>>.from(decoded);
        } else {
          homeworks = [];
        }
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to load homeworks (${response.statusCode})",
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint("❌ fetchHomeworks error: $e");
    if (!mounted) return;
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Error loading homework")),
    );
  }
}

  // ---------------- DATE FORMAT ----------------
  String formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }

  // ---------------- FILE DOWNLOAD (IOS + ANDROID SAFE) ----------------
  Future<void> downloadFile(BuildContext context, String attachmentPath) async {
    try {
      final String fileUrl = attachmentPath.startsWith('http')
          ? attachmentPath
          : 'https://schoolerp.edusathi.in/$attachmentPath';

      final response = await http
          .get(Uri.parse(fileUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception("Download failed");
      }

      final Directory dir = await getApplicationDocumentsDirectory();
      final String fileName = attachmentPath.split('/').last;
      final File file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("📥 Downloaded to ${file.path}")),
        );
      }

      await OpenFile.open(file.path);
    } catch (e) {
      if (context.mounted) {
        debugPrint("Download error: $e");

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("❌ Download error")),
        // );
      }
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Homeworks'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : homeworks.isEmpty
              ? const Center(child: Text('No homework found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: homeworks.length,
                  itemBuilder: (context, index) {
                    final hw = homeworks[index];
                    final attachmentUrl = hw['Attachment'];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherHomeworkDetailPage(homework: hw),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hw['HomeworkTitle'] ?? 'Untitled',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "📅 ${formatDate(hw['WorkDate'])}",
                                    style:
                                        const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    "Submission: ${formatDate(hw['SubmissionDate'])}",
                                    style:
                                        const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if ((hw['Remark'] ?? '').isNotEmpty)
                                Text(
                                  "📝 ${(hw['Remark'] as String).length > 150 ? hw['Remark'].substring(0, 150) + '...' : hw['Remark']}",
                                  style:
                                      const TextStyle(fontSize: 13),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.deepPurple,
                                    ),
                                    onPressed: () async {
                                      final result =
                                          await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TeacherAddHomeworkPage(
                                            homeworkToEdit: hw,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        fetchHomeworks();
                                      }
                                    },
                                  ),
                                  if (attachmentUrl != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.download_rounded,
                                        color: Colors.deepPurple,
                                      ),
                                      onPressed: () {
                                        downloadFile(
                                          context,
                                          attachmentUrl,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherAddHomeworkPage(),
            ),
          );
          if (result == true) {
            fetchHomeworks();
          }
        },
      ),
    );
  }
}
