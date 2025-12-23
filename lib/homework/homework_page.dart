import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:edusathi_v2/auth_helper.dart';
import 'package:edusathi_v2/homework/homework_detail_page.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  List<dynamic> homeworks = [];
  bool isLoading = true;
  bool _isDownloading = false; // 🔒 download lock

  @override
  void initState() {
    super.initState();
    fetchHomework();
  }

  // =========================
  // 📡 FETCH HOMEWORK
  // =========================
  Future<void> fetchHomework() async {
    try {
      final response = await AuthHelper.post(
        context,
        'https://schoolerp.edusathi.in/api/student/homework',
      );

      // 🔴 Token expired / auto logout
      if (response == null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;
        setState(() {
          homeworks = data;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load homework");
      }
    } catch (e) {
      debugPrint("❌ fetchHomework error: $e");

      if (!mounted) return;
      setState(() {
        isLoading = false;
        homeworks = [];
      });
    }
  }

  // =========================
  // 📅 DATE FORMAT
  // =========================
  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  // =========================
  // 📥 SAFE FILE DOWNLOAD
  // =========================
  Future<void> downloadFile(BuildContext context, String filePath) async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      final token = await AuthHelper.getToken();
      if (token.isEmpty) throw Exception("No token");

      final fullUrl = filePath.startsWith('http')
          ? filePath
          : 'https://schoolerp.edusathi.in/$filePath';

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception("Download failed");
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = fullUrl.split('/').last;
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Downloaded to ${file.path}")));

      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint("❌ download error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Download failed")));
    } finally {
      _isDownloading = false;
    }
  }

  // =========================
  // 🧱 UI (UNCHANGED)
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : homeworks.isEmpty
          ? const Center(child: Text("No homework available"))
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
                        builder: (_) => HomeworkDetailPage(homework: hw),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "📅 ${formatDate(hw['WorkDate'])}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  "Submission: ${formatDate(hw['SubmissionDate'])}",
                                  style: const TextStyle(fontSize: 13),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if ((hw['Remark'] ?? '').isNotEmpty)
                            Text(
                              "📝 ${(hw['Remark'] as String).length > 150 ? hw['Remark'].substring(0, 150) + '...' : hw['Remark']}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          if (attachmentUrl != null)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.deepPurple,
                                ),
                                onPressed: () {
                                  downloadFile(context, attachmentUrl);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
