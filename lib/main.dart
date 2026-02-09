import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:fyp/common/splash_screen.dart';
import 'package:fyp/common/login.dart';
import 'package:fyp/common/sign_up.dart';
import 'package:fyp/common/profile.dart';
import 'package:fyp/common/reset_password.dart';
import 'package:fyp/reportswork/dashboard.dart';
import 'package:fyp/reportswork/new_reports.dart';
import 'package:fyp/reportswork/upload_video.dart';
import 'package:fyp/patient/patient_dashboard_screen.dart';

User? currentUser;

void main() async {
  // 1. Flutter engine initialize
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Check if user is already logged in
  currentUser = FirebaseAuth.instance.currentUser;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Endoscopy AI Portal',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        primaryColor: const Color(0xFF2563EB), // Doctor Blue
        scaffoldBackgroundColor: Colors.grey[50],
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF009688), // Patient Teal
        ),
      ),

      // Initial Screen
      initialRoute: '/',

      // --- DYNAMIC ROUTE GENERATION (Complex Routes) ---
      onGenerateRoute: (settings) {
        // 1. Doctor Dashboard
        if (settings.name == '/home') {
          return MaterialPageRoute(builder: (context) => const DashboardScreen());
        }

        // 2. New Report Entry
        if (settings.name == '/new_report') {
          return MaterialPageRoute(builder: (context) => const NewReportScreen());
        }

        // 3. Upload Video (Arguments Required)
        if (settings.name == '/upload_video') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (context) => UploadVideoScreen(patientData: args),
          );
        }

        return null;
      },

      // --- STATIC ROUTES (Simple Routes) ---
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/profile': (context) => const ProfileScreen(),

        // --- ADDED PATIENT DASHBOARD ROUTE ---
        '/patient_home': (context) => const PatientDashboardScreen(),
      },
    );
  }
}