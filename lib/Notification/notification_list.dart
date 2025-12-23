import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusathi_v2/complaint/complaint_detail_page.dart';
import 'package:edusathi_v2/dashboard/dashboard_screen.dart';
import 'package:edusathi_v2/Attendance_UI/stu_attendance_page.dart';
import 'package:edusathi_v2/homework/homework_detail_page.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final url = Uri.parse(
        "https://schoolerp.edusathi.in/api/student/notifications",
      );
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print("🔑 Token: $token");

      final response = await http.post(url, headers: headers);
      print("📥 Status: ${response.statusCode}");
      print("📥 Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          setState(() {
            notifications = data['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("🚨 Error fetching notifications: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleNotificationTap(String type, int id, Map<String, dynamic> item) {
    if (type == "homework") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HomeworkDetailPage(homework: item)),
      );
    } else if (type == "attendance") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AttendanceAnalyticsPage()),
      );
    } else if (type == "complaint") {
      final complaintId = id;
      final date =
          notifications.firstWhere((item) => item["id"] == id)["date"] ?? "";
      final description =
          notifications.firstWhere((item) => item["id"] == id)["description"] ??
          "";
      final status =
          notifications.firstWhere((item) => item["id"] == id)["status"] ?? "";
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintDetailPage(
            complaintId: complaintId,
            date: date,
            description: description,
            status: status,
          ),
        ),
      );
    } else if ([
      "notice",
      "event",
      "student alert",
      "due reminder",
    ].contains(type)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No screen mapped for type: $type")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(child: Text("No notifications available"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                final type = item["type"] ?? "";
                final id = item["id"];
                final date = item["date"] ?? "";
                final time = item["time"] ?? "";

                final title = type == "homework"
                    ? item["HomeworkTitle"] ?? item["title"] ?? "Homework Title"
                    : item["title"] ?? "No Title";

                final description = type == "homework"
                    ? item["Remark"] ?? item["description"] ?? ""
                    : item["description"] ?? "";

                return GestureDetector(
                  onTap: () => handleNotificationTap(type, id, item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon section
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: type == "homework"
                              ? Colors.pink.shade50
                              : type == "attendance"
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          child: Icon(
                            type == "homework"
                                ? Icons.menu_book_rounded
                                : type == "attendance"
                                ? Icons.check_circle_outline
                                : Icons.notifications_active_outlined,
                            color: type == "homework"
                                ? Colors.pink
                                : type == "attendance"
                                ? Colors.blue
                                : Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Text section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
