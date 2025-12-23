import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:edusathi_v2/teacher/teacher_homework_detail_page.dart';
import 'package:edusathi_v2/teacher/teacher_homework_page.dart';

class TeacherRecentHomeworks extends StatelessWidget {
  final List<Map<String, dynamic>> homeworks;

  const TeacherRecentHomeworks({super.key, required this.homeworks});

  @override
  Widget build(BuildContext context) {
    final limitedHomeworks = homeworks.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📝 Recent Homeworks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeacherHomeworkPage()),
                  );
                },
                child: const Text("View All"),
              ),
            ],
          ),
          limitedHomeworks.isEmpty
              ? const Text("No homeworks available.")
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: limitedHomeworks.length,
                  itemBuilder: (context, index) {
                    final hw = limitedHomeworks[index];

                    return ListTile(
                      leading:
                          const Icon(Icons.book, color: Colors.deepPurple),
                      title: Text(hw['HomeworkTitle'] ?? ''),
                      subtitle: Text(
                        "Submission: ${formatDate(hw['SubmissionDate'])}",
                      ),
                      trailing: hw['Attachment'] != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.deepPurple,
                              ),
                              onPressed: () async {
                                await _requestStoragePermission();

                                final attachment = hw['Attachment'];
                                final fileUrl =
                                    'https://schoolerp.edusathi.in/$attachment';
                                final fileName =
                                    Uri.parse(fileUrl).pathSegments.last;

                                await _downloadFile(
                                  context,
                                  fileUrl,
                                  fileName,
                                );
                              },
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherHomeworkDetailPage(homework: hw),
                          ),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  // ---------------- PERMISSION (ANDROID ONLY) ----------------
  static Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
    } else {
      await Permission.storage.request();
    }
  }

  // ---------------- SAFE FILE DOWNLOAD ----------------
  static Future<void> _downloadFile(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception("File download failed");
      }

      // ✅ iOS + Android safe directory
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📥 Downloaded to $filePath")),
      );

      await OpenFile.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Download failed")),
      );
    }
  }
}

// ---------------- DATE FORMAT ----------------
String formatDate(String? date) {
  if (date == null || date.isEmpty) return "";
  try {
    final parsedDate = DateTime.parse(date);
    return "${parsedDate.day.toString().padLeft(2, '0')}-"
        "${parsedDate.month.toString().padLeft(2, '0')}-"
        "${parsedDate.year}";
  } catch (_) {
    return date;
  }
}
