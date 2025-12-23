import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edusathi_v2/dashboard/dashboard_screen.dart';
import 'package:edusathi_v2/login_page.dart';
import 'package:edusathi_v2/teacher/teacher_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userType = prefs.getString('user_type') ?? '';

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (token.isNotEmpty) {
            return userType == 'Teacher'
                ? const TeacherDashboardScreen()
                : const DashboardScreen();
          } else {
            return LoginPage();
          }
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 120),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}
