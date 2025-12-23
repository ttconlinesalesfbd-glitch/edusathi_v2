import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:edusathi_v2/dashboard/dashboard_screen.dart';
import 'package:edusathi_v2/splash_screen.dart';
// import 'package:edusathi_v2/teacher/teacher_dashboard_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String baseUrl = "https://schoolerp.edusathi.in/api";
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  String _errorMessage = '';
  String selectedRole = 'Student';

  final FlutterSecureStorage secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (idController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter ID and password");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    debugPrint("🚀 LOGIN STARTED");
    debugPrint("👤 ROLE: $selectedRole");
    debugPrint("👤 USERNAME: ${idController.text.trim()}");

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': idController.text.trim(),
              'password': passwordController.text,
              'type': selectedRole,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("🟢 LOGIN STATUS: ${response.statusCode}");
      debugPrint("🟢 LOGIN BODY: ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("Server error ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (data['status'] == true && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();

        // 🔐 SAVE SESSION FLAGS (REQUIRED FOR ANDROID)

        await prefs.setString('user_type', data['user_type'] ?? '');

        // ✅ CRITICAL FIX (ANDROID NEEDS THIS)
        await prefs.setString('auth_token', data['token']);

        // 🔐 SAVE TOKEN SECURELY (IOS SAFE)
        await secureStorage.write(key: 'auth_token', value: data['token']);

        debugPrint("✅ LOGIN SUCCESS");
        debugPrint("🔑 TOKEN SAVED (Secure + Prefs)");
        debugPrint("👤 USER TYPE: ${data['user_type']}");

        final profile = data['profile'] ?? {};

        if (data['user_type'] == 'Student') {
          await prefs.setString('student_name', profile['student_name'] ?? '');
          await prefs.setString(
            'student_photo',
            profile['student_photo'] ?? '',
          );
          await prefs.setString('class_name', profile['class_name'] ?? '');
          await prefs.setString('section', profile['section'] ?? '');
          await prefs.setString('school_name', profile['school_name'] ?? '');
          // 🟢 DEBUG PRINTS (STUDENT)
          debugPrint("🧑 STUDENT NAME: ${prefs.getString('student_name')}");
          debugPrint("🖼️ STUDENT PHOTO: ${prefs.getString('student_photo')}");
          debugPrint("🏫 SCHOOL NAME: ${prefs.getString('school_name')}");
          debugPrint("🏷️ CLASS: ${prefs.getString('class_name')}");
          debugPrint("📘 SECTION: ${prefs.getString('section')}");
        } else {
          await prefs.setString('teacher_name', profile['name'] ?? '');
          await prefs.setString('school_name', profile['school'] ?? '');
          await prefs.setString('teacher_photo', profile['photo'] ?? '');
          await prefs.setString('teacher_class', profile['class'] ?? '');
          await prefs.setString('teacher_section', profile['section'] ?? '');
        }

        debugPrint(
          "🔐 AUTH TOKEN (SECURE): ${await secureStorage.read(key: 'auth_token')}",
        );
        debugPrint("💾 PROFILE SAVED");
        passwordController.clear();

        if (!mounted) return;

        debugPrint("➡️ NAVIGATING TO DASHBOARD");

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
        return;
      } else {
        debugPrint("❌ LOGIN FAILED: ${data['message']}");
        setState(() {
          _errorMessage = data['message'] ?? "Invalid login credentials";
        });
      }
    } on TimeoutException {
      debugPrint("⏱️ LOGIN TIMEOUT");
      setState(() => _errorMessage = "Server timeout. Please try again.");
    } catch (e) {
      debugPrint("🚨 LOGIN EXCEPTION: $e");
      setState(() => _errorMessage = "Login failed. Please try again.");
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint("🔚 LOGIN PROCESS END");
    }
  }

  Future<void> sendFcmTokenToLaravel() async {
    final authToken = await secureStorage.read(key: 'auth_token');
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (authToken == null || authToken.isEmpty) {
      debugPrint('❌ Auth token missing');
      return;
    }

    if (fcmToken == null) {
      debugPrint('❌ FCM token not found');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://schoolerp.edusathi.in/api/save_token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      debugPrint("🔵 FCM Status: ${response.statusCode}");
    } catch (e) {
      debugPrint("❌ FCM Error: $e");
    }
  }

  void _launchURL() async {
    final Uri url = Uri.parse('https://www.techinnovationapp.in');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Widget roleToggleSwitch() {
    return Container(
      width: 250,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Student tab
          Expanded(
            child: InkWell(
              onTap: () => setState(() => selectedRole = 'Student'),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: selectedRole == 'Student'
                      ? LinearGradient(
                          colors: [Colors.purple, Colors.deepPurple],
                        )
                      : null,
                ),
                child: Text(
                  "Student",
                  style: TextStyle(
                    color: selectedRole == 'Student'
                        ? Colors.white
                        : Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Teacher tab
          Expanded(
            child: InkWell(
              onTap: () => setState(() => selectedRole = 'Teacher'),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: selectedRole == 'Teacher'
                      ? LinearGradient(
                          colors: [Colors.purple, Colors.deepPurple],
                        )
                      : null,
                ),
                child: Text(
                  "Teacher",
                  style: TextStyle(
                    color: selectedRole == 'Teacher'
                        ? Colors.white
                        : Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = selectedRole == 'Student';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white, Colors.white]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', height: 80),
                  SizedBox(height: 10),
                  Text(
                    "Edusathi School",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Empowering Education, Simplifying Management.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 20),
                  roleToggleSwitch(),
                  SizedBox(height: 30),

                  Text(
                    "$selectedRole Login",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 20),

                  TextField(
                    controller: idController,
                    decoration: InputDecoration(
                      labelText: isStudent ? "Student ID" : "Teacher ID",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),

                  TextField(
                    controller: passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  if (_errorMessage.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 16),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 20),

                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        "Designed & Developed by ",
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        "TechInnovationApp",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 5),
                      Text("Visit our website", style: TextStyle(fontSize: 12)),
                      GestureDetector(
                        onTap: _launchURL,
                        child: Text(
                          "www.techinnovationapp.in",
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
