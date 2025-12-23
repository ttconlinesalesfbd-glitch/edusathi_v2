import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class TeacherHomeworkDetailPage extends StatelessWidget {
  final Map<String, dynamic> homework;

  const TeacherHomeworkDetailPage({
    super.key,
    required this.homework,
  });

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    } catch (_) {
      return dateStr;
    }
  }

  // ---------------- PERMISSION (ANDROID ONLY) ----------------
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    PermissionStatus status;
    if (sdkInt >= 33) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
    }

    return status.isGranted;
  }

  // ---------------- DOWNLOAD FILE ----------------
  Future<void> downloadFile(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    try {
      // 📂 Platform-safe directory
      final Directory dir = Platform.isAndroid
          ? (await getExternalStorageDirectory())!
          : await getApplicationDocumentsDirectory();

      final String filePath = '${dir.path}/$fileName';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception("Failed to download file");
      }

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("📥 Downloaded to $filePath")),
        );
      }

      await OpenFile.open(filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Download failed")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = homework['Attachment'];
    final String? fileName =
        attachment != null ? attachment.split('/').last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Homework Details",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homework['HomeworkTitle'] ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Assignment: ${formatDate(homework['WorkDate'])}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    "Submission: ${formatDate(homework['SubmissionDate'])}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "📝 Remark:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(homework['Remark'] ?? 'No remarks provided'),
              const SizedBox(height: 20),
              if (attachment != null && fileName != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    onPressed: () async {
                      final hasPermission =
                          await requestStoragePermission();
                      if (!hasPermission) return;

                      final fileUrl =
                          'https://schoolerp.edusathi.in/$attachment';

                      await downloadFile(
                        context,
                        fileUrl,
                        fileName,
                      );
                    },
                    icon:
                        const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      "Download Attachment",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
