import 'dart:convert';
import 'dart:io';
import 'package:edusathi_v2/Attendance_UI/attendance_box.dart';
import 'package:edusathi_v2/dashboard/stu_result.dart';
import 'package:edusathi_v2/exam_schedule.dart';
import 'package:edusathi_v2/syllabus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusathi_v2/Attendance_UI/stu_attendance_page.dart';

import 'package:edusathi_v2/Attendance_UI/attendance_pie_chart.dart';
import 'package:edusathi_v2/Notification/notification_list.dart';
import 'package:edusathi_v2/connect_teacher/connect_with_us.dart';
// import 'package:edusathi_v2/connect_teacher/student_chat.dart';
import 'package:edusathi_v2/dashboard/calendar.dart';
import 'package:edusathi_v2/homework/homework_model.dart';
import 'package:edusathi_v2/homework/homework_page.dart';
import 'package:edusathi_v2/dashboard/timetable_page.dart';
import 'package:edusathi_v2/login_page.dart';
import 'package:edusathi_v2/payment/fee_details_page.dart';
import 'package:edusathi_v2/payment/payment_page.dart';
import 'package:edusathi_v2/profile_page.dart';
import 'package:edusathi_v2/school_info_page.dart';
import 'package:edusathi_v2/complaint/view_complaints_page.dart';
import 'package:edusathi_v2/subjects_page.dart';

import 'package:edusathi_v2/Attendance_UI/stu_attendance_report.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = true;

  String studentName = '';
  String studentPhoto = '';
  String schoolName = '';
  String studentClass = '';
  String studentsection = '';

  int dues = 0;
  int payments = 0;
  String lastPaymentDate = '';
  int subjects = 0;
  String status = '';
  Map<String, dynamic> attendance = {};
  List<Map<String, dynamic>> homeworks = [];
  List<dynamic> notices = [];
  List<dynamic> events = [];
  List<dynamic> siblings = [];
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    await loadProfileData();
    await fetchDashboardData(context);
    setState(() {
      isLoading = false;
    });
  }

  Future<String> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ Secure storage (PRIMARY)
    final secureToken = await secureStorage.read(key: 'auth_token');
    if (secureToken != null && secureToken.isNotEmpty) {
      debugPrint("🔐 TOKEN FROM SECURE STORAGE");
      return secureToken;
    }

    // 2️⃣ SharedPreferences fallback (ANDROID SAFETY)
    final prefsToken = prefs.getString('auth_token') ?? '';
    if (prefsToken.isNotEmpty) {
      debugPrint("🔐 TOKEN FROM SHARED PREFS");
      return prefsToken;
    }

    debugPrint("❌ NO TOKEN FOUND");
    return '';
  }

  Future<void> loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    studentName = prefs.getString('student_name') ?? '';
    studentPhoto = prefs.getString('student_photo') ?? '';
    schoolName = prefs.getString('school_name') ?? '';
    studentClass = prefs.getString('class_name') ?? '';
    studentsection = prefs.getString('section') ?? '';
  }

  Future<void> fetchDashboardData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getAuthToken();

    debugPrint("📡 DASHBOARD TOKEN: $token");

    if (token.isEmpty) {
      debugPrint("🚨 EMPTY TOKEN → FORCE LOGOUT");

      await secureStorage.delete(key: 'auth_token');
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (_) => false,
      );
      return;
    }

    final response = await http.post(
      Uri.parse('https://schoolerp.edusathi.in/api/student/dashboard'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    debugPrint("🔵 DASHBOARD STATUS: ${response.statusCode}");
    debugPrint("🔵 DASHBOARD BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      dues = data['dues'] ?? 0;
      payments = int.tryParse(data['payments'].toString()) ?? 0;

      final rawDate = data['payment_date'] ?? '';
      if (rawDate.isNotEmpty) {
        try {
          final dateObject = DateTime.parse(rawDate);
          lastPaymentDate =
              '${dateObject.day}/${dateObject.month}/${dateObject.year}';
        } catch (_) {
          lastPaymentDate = rawDate;
        }
      }

      status = data['today_status'] ?? '';
      subjects = data['subjects'] ?? 0;

      attendance = {
        'present': data['attendances']?['present'] ?? 0,
        'absent': data['attendances']?['absent'] ?? 0,
        'leave': data['attendances']?['leave'] ?? 0,
        'half_day': data['attendances']?['half_day'] ?? 0,
        'working_days': data['attendances']?['working_days'] ?? 0,
      };

      homeworks = List<Map<String, dynamic>>.from(data['homeworks'] ?? []);
      notices = data['notices'] ?? [];
      events = data['events'] ?? [];
      siblings = data['siblings'] ?? [];

      return;
    }

    if (response.statusCode == 401) {
      debugPrint("🚫 DASHBOARD 401 → SESSION EXPIRED");

      await secureStorage.delete(key: 'auth_token');
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (_) => false,
      );
    }
  }

  void _showSiblingPopup(BuildContext context) {
    if (siblings.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Siblings'),
          content: const Text('No siblings available for this student.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.people, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Switch Sibling',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: siblings.length,
            itemBuilder: (context, index) {
              final sibling = siblings[index];
              final photoUrl =
                  sibling['Photo'] != null &&
                      sibling['Photo'].toString().isNotEmpty
                  ? sibling['Photo'].toString()
                  : 'https://schoolerp.edusathi.in/uploads/no_image.png';

              final name = sibling['Name'] ?? 'Unknown';
              final className = sibling['Class'].toString();

              final studentId = sibling['id'].toString();

              print('🧠 Sibling Data: $sibling');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(photoUrl),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Class: $className'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () {
                    // 🔹 Show confirmation dialog before switching
                    showDialog(
                      context: context,
                      builder: (BuildContext confirmContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          title: const Text(
                            'Confirm Switch',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'Are you sure you want to switch to $name?',
                            style: const TextStyle(fontSize: 15),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmContext),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(
                                  confirmContext,
                                ); // close confirm dialog
                                Navigator.pop(
                                  context,
                                ); // close sibling list dialog safely
                                if (!mounted) return;
                                await _shiftLogin(studentId);
                              },
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Yes, Switch'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shiftLogin(String studentId) async {
    if (!mounted) return;
    try {
      // Step 1: Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();

      // Step 2: Get saved token before making request
      final token = await getAuthToken();

      print('🔑 Using Token: $token');

      // Step 3: Prepare API request
      final url = Uri.parse(
        'https://schoolerp.edusathi.in/api/student/shift_login',
      );
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = {'id': studentId};
      print('📤 Request Body: $body');

      // Step 4: Send request
      final response = await http.post(url, headers: headers, body: body);

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      // Step 5: Handle non-200 responses
      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error (${response.statusCode})')),
        );
        return;
      }

      // Step 6: Decode JSON
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        print('❌ Failed to decode response as JSON');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid server response')),
        );
        return;
      }

      // Step 7: Handle response data
      if (data['status'] == true) {
        print('✅ Shift Login Successful for ID: $studentId');

        await secureStorage.write(key: 'auth_token', value: data['token']);
        await prefs.setString('auth_token', data['token']);

        await prefs.setString('user_type', data['user_type'] ?? '');
        await prefs.setString(
          'student_name',
          data['profile']['student_name'] ?? '',
        );
        await prefs.setString(
          'class_name',
          data['profile']['class_name'] ?? '',
        );
        await prefs.setString('section', data['profile']['section'] ?? '');
        await prefs.setString(
          'school_name',
          data['profile']['school_name'] ?? '',
        );
        await prefs.setString(
          'student_photo',
          data['profile']['student_photo'] ?? '',
        );

        print('💾 New Token Saved: ${data['token']}');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switched student successfully')),
        );

        // Navigate fresh to dashboard/home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen()),
        );
      } else {
        print('❌ Shift login failed: ${data['message']}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Login failed')),
        );
      }
    } catch (e) {
      print('🚨 Exception in _shiftLogin: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: isLoading
          ? null
          : LeftSidebarMenu(
              studentName: studentName,
              studentPhoto: studentPhoto,
              studentClass: studentClass,
              studentsection: studentsection,
            ),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$schoolName',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              child: Icon(Icons.calendar_month_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentCalendarPage()),
              ),
            ),
            SizedBox(width: 5),
            GestureDetector(
              child: Icon(Icons.notifications),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationListPage()),
              ),
            ),
            SizedBox(width: 5),
            GestureDetector(
              onTap: () => _showSiblingPopup(context),
              child: CircleAvatar(
                backgroundImage: studentPhoto.isNotEmpty
                    ? NetworkImage(studentPhoto)
                    : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                radius: 15,
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        child: DashboardCard(
                          title: 'Fee Amount',
                          value: dues.toString(),
                          borderColor: Colors.red,
                          backgroundColor: Colors.red.shade50,
                          textColor: Colors.red,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FeeDetailsPage()),
                        ),
                      ),
                      GestureDetector(
                        child: DashboardCard(
                          title: 'Last Pay',
                          value: payments.toString(),
                          borderColor: Colors.green,
                          backgroundColor: Colors.green.shade50,
                          textColor: Colors.green,
                          date: lastPaymentDate,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PaymentPage()),
                        ),
                      ),
                      GestureDetector(
                        child: DashboardCard(
                          title: 'Subjects',
                          value: subjects.toString(),
                          borderColor: Colors.blue,
                          backgroundColor: Colors.blue.shade50,
                          textColor: Colors.blue,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SubjectsPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    child: AttendanceCard(
                      title: "Today's Attendance",
                      place: "School",
                      status: status,
                      icon: Icons.school,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceAnalyticsPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 225,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade100),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                      ],
                    ),
                    child: AttendancePieChart(
                      present: attendance['present'] ?? 0,
                      absent: attendance['absent'] ?? 0,
                      leave: attendance['leave'] ?? 0,
                      halfDay: attendance['half_day'] ?? 0,
                      workingDays: attendance['working_days'] ?? 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  buildRecentHomeworks(context, homeworks),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 350,
                    child: NoticesEventsToggle(
                      initialNotices: notices,
                      initialEvents: events,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;
  final String? date;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 88,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          if (date != null && date!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 0.0, bottom: 2.0),
              child: Text(
                date!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            )
          else
            const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isEvent;
  final String baseUrl = 'https://schoolerp.edusathi.in/';

  const InfoCard({super.key, required this.item, required this.isEvent});

  Future<void> _launchUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open attachment link.')),
      );
    }
  }

  Future<void> _downloadFile(BuildContext context, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception(
          "Failed to download file. Status: ${response.statusCode}",
        );
      }
      final dir = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloaded and saved to: ${dir.path}/$fileName"),
        ),
      );
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Download error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = isEvent ? "EventTitle" : "NoticeTitle";
    String formatDate(String? inputDate) {
      if (inputDate == null || inputDate.isEmpty) return '';
      try {
        final date = DateTime.parse(inputDate);
        return DateFormat('dd-MM-yyyy').format(date);
      } catch (e) {
        return inputDate;
      }
    }

    final Color primaryColor = isEvent
        ? Colors.orange.shade700
        : Colors.indigo.shade700;
    final Color lightColor = isEvent
        ? Colors.orange.shade50
        : Colors.indigo.shade50;

    final String? attachmentPath = item["Attachment"];
    final bool hasAttachment =
        attachmentPath != null && attachmentPath.isNotEmpty;
    final String fullAttachmentUrl = hasAttachment
        ? baseUrl + attachmentPath
        : '';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor, width: 1.5),
      ),
      color: lightColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item[titleKey] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatDate(item["Date"] ?? 'N/A'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const Divider(height: 16),

            Text(
              item["Description"] ?? 'No description provided.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (hasAttachment) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text("View Attachment"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),

                    onPressed: () => _launchUrl(context, fullAttachmentUrl),
                  ),

                  const SizedBox(width: 25),

                  IconButton(
                    onPressed: () => _downloadFile(context, fullAttachmentUrl),
                    icon: Icon(Icons.download, color: primaryColor, size: 24),
                    tooltip: 'Download Attachment',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoticesEventsToggle extends StatelessWidget {
  final List<dynamic> initialNotices;
  final List<dynamic> initialEvents;

  const NoticesEventsToggle({
    super.key,
    required this.initialNotices,
    required this.initialEvents,
  });
  Widget _buildList(List<dynamic> data, {required bool isEvent}) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          isEvent ? 'No upcoming events.' : 'No new notices posted.',
          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index] as Map<String, dynamic>;
        return InfoCard(item: item, isEvent: isEvent);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurple, width: 1),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.deepPurple,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.deepPurple,
                splashBorderRadius: BorderRadius.circular(20),
                tabs: const [
                  Tab(text: 'Notices'),
                  Tab(text: 'Events'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _buildList(initialNotices, isEvent: false),

                _buildList(initialEvents, isEvent: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LeftSidebarMenu extends StatelessWidget {
  final String studentName;
  final String studentPhoto;
  final String studentClass;
  final String studentsection;

  const LeftSidebarMenu({
    super.key,
    required this.studentName,
    required this.studentPhoto,
    required this.studentClass,
    required this.studentsection,
  });
  Future<String> _getTokenForLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = const FlutterSecureStorage();

    final secureToken = await storage.read(key: 'auth_token');
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    return prefs.getString('auth_token') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Drawer(
        child: ListView(
          children: [
            Container(
              color: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              height: 120,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: studentPhoto.isNotEmpty
                        ? NetworkImage(studentPhoto)
                        : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          studentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Class: $studentClass',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Section: ${studentsection.isNotEmpty ? studentsection : "-"}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            sidebarTile(
              icon: Icons.dashboard,
              title: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),
            sidebarTile(
              icon: Icons.person,
              title: 'Profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfilePage()),
                );
              },
            ),

            sidebarTile(
              icon: Icons.book,
              title: 'Homeworks',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HomeworkPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.calendar_month,
              title: 'Attendance',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentAttendanceScreen()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.calendar_today,
              title: 'Time-Table',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimeTablePage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.calendar_month,
              title: 'Calendar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentCalendarPage()),
                );
              },
            ),

            sidebarTile(
              icon: Icons.subject,
              title: 'Subjects',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SubjectsPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.book_sharp,
              title: 'Syllabus',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SyllabusPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.receipt_long_outlined,
              title: 'Exam Schedule',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExamSchedulePage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.report,
              title: 'Complaint',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewComplaintPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.attach_money,
              title: 'Fees',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeeDetailsPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.payment,
              title: 'Payment',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.list_alt_outlined,
              title: 'Result',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentResultPage()),
                );
              },
            ),
            sidebarTile(
              icon: Icons.school,
              title: 'School Info',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SchoolInfoPage()),
                );
              },
            ),

            sidebarTile(
              icon: Icons.support_agent,
              title: 'Contact & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConnectWithUsPage(
                      teacherId: 0,
                      teacherName: '',
                      teacherPhoto: '',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        child: const Text("Logout"),
                        onPressed: () async {
                          Navigator.pop(dialogContext); // close dialog

                          final prefs = await SharedPreferences.getInstance();
                          const storage = FlutterSecureStorage();
                          final token = await _getTokenForLogout();

                          debugPrint("🔐 LOGOUT TOKEN: $token");

                          try {
                            final response = await http.post(
                              Uri.parse(
                                'https://schoolerp.edusathi.in/api/logout',
                              ),
                              headers: {
                                'Authorization': 'Bearer $token',
                                'Accept': 'application/json',
                              },
                            );

                            debugPrint(
                              "🔐 Logout Status: ${response.statusCode}",
                            );
                            debugPrint("🔐 Logout Body: ${response.body}");

                            // ✅ ALWAYS clear local session
                            await storage.delete(key: 'auth_token');
                            await prefs.clear();

                            if (!context.mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                              (_) => false,
                            );
                          } catch (e) {
                            debugPrint("🚨 LOGOUT ERROR: $e");

                            await storage.delete(key: 'auth_token');
                            await prefs.clear();

                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                              (_) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget sidebarTile({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
    visualDensity: VisualDensity(vertical: -2),

    leading: Icon(icon),
    title: Text(title),
    onTap: onTap,
  );
}
