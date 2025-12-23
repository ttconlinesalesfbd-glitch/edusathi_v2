import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:edusathi_v2/splash_screen.dart';
import 'package:edusathi_v2/dashboard/dashboard_screen.dart';
import 'package:edusathi_v2/teacher/teacher_dashboard_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔔 Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ✅ Firebase init (SAFE for iOS/TestFlight)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const RootDecider(),
    );
  }
}

/// 🔥 SAFE ROOT DECIDER (iOS + TestFlight ready)
class RootDecider extends StatefulWidget {
  const RootDecider({super.key});

  @override
  State<RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<RootDecider> {
  Widget _screen = const SplashScreen();

  final FlutterSecureStorage secureStorage =
      const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final userType = prefs.getString('user_type') ?? '';

      /// 🔐 CRITICAL: Validate token also
      final token =
          await secureStorage.read(key: 'auth_token') ?? '';

      if (isLoggedIn && token.isNotEmpty) {
        if (userType == 'Teacher') {
          _screen = const TeacherDashboardScreen();
        } else if (userType == 'Student') {
          _screen = const DashboardScreen();
        } else {
          _screen = const SplashScreen();
        }
      } else {
        /// ❌ Invalid session → clean
        await secureStorage.delete(key: 'auth_token');
        await prefs.clear();
        _screen = const SplashScreen();
      }
    } catch (_) {
      _screen = const SplashScreen();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _screen;
  }
}
