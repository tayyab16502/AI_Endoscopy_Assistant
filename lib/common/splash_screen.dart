import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore Import Zaroori hai
import 'package:fyp/main.dart'; // Global currentUser access

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _entranceController;
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    // --- ANIMATIONS SETUP ---
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 3 Seconds ka wait, phir checking shuru
    Timer(const Duration(seconds: 3), () {
      _checkUserAndNavigate();
    });
  }

  // --- MAIN LOGIC: CHECK ROLE & NAVIGATE ---
  Future<void> _checkUserAndNavigate() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // 1. User Status Reload (Taake confirm ho account active hai)
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser == null) {
          _handleLogout();
          return;
        }

        // Global Variable Set karein
        currentUser = refreshedUser;

        if (mounted) {
          // 2. CHECK FIRESTORE COLLECTIONS (Priority Wise)

          // STEP A: Check 'doctors' Collection
          DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(refreshedUser.uid)
              .get();

          if (doctorDoc.exists) {
            _navigateToDoctorDashboard(); // Doctor mila -> Doctor Dashboard
            return;
          }

          // STEP B: Check 'patients' Collection
          DocumentSnapshot patientDoc = await FirebaseFirestore.instance
              .collection('patients')
              .doc(refreshedUser.uid)
              .get();

          if (patientDoc.exists) {
            _navigateToPatientDashboard(); // Patient mila -> Patient Dashboard
            return;
          }

          // STEP C: Check 'users' Collection (Purana data fallback)
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

          if (userDoc.exists) {
            String role = userDoc['role'] ?? 'doctor';
            if (role == 'patient') {
              _navigateToPatientDashboard();
            } else {
              _navigateToDoctorDashboard();
            }
            return;
          }

          // STEP D: Data kahin nahi mila (Account hai par Data nahi) -> Logout
          _handleLogout();
        }
      } catch (e) {
        // Agar internet error ho, to safe side logout kar dein ya login screen dikhayen
        debugPrint("Splash Error: $e");
        _handleLogout();
      }
    } else {
      // User login nahi hai
      _handleLogout();
    }
  }

  // --- NAVIGATION FUNCTIONS ---
  void _navigateToDoctorDashboard() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _navigateToPatientDashboard() {
    if (mounted) {
      // Make sure main.dart ma ye route defined ho
      Navigator.of(context).pushReplacementNamed('/patient_home');
    }
  }

  void _handleLogout() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  // --- UI DESIGN (ANIMATED) ---
  @override
  Widget build(BuildContext context) {
    const Color blue600 = Color(0xFF2563EB);
    const Color indigo600 = Color(0xFF4F46E5);
    const Color purple600 = Color(0xFF9333EA);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [blue600, indigo600, purple600],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -10 * (1 - _bounceController.value)),
                  child: child,
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 32),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Center(
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController),
                    child: const Icon(Icons.monitor_heart_outlined, color: blue600, size: 56),
                  ),
                ),
              ),
            ),
            _buildFadeInSlide(
              delay: 0,
              child: const Text("Endoscopy Report", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            _buildFadeInSlide(
              delay: 200,
              child: const Text("AI-Powered Medical Reporting System", style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 16)),
            ),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (index) => _buildPulsingDot(index))),
            const SizedBox(height: 48),
            _buildFadeInSlide(
              delay: 400,
              child: const Text("Version 1.0.0", style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFadeInSlide({required int delay, required Widget child}) {
    final double startInterval = delay / 1500.0;
    final double endInterval = (delay + 600) / 1500.0;
    final Animation<double> opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Interval(startInterval, endInterval, curve: Curves.easeOut)),
    );
    final Animation<Offset> slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Interval(startInterval, endInterval, curve: Curves.easeOut)),
    );
    return SlideTransition(position: slideAnimation, child: FadeTransition(opacity: opacityAnimation, child: child));
  }

  Widget _buildPulsingDot(int index) {
    final double delay = index * 0.15;
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final double value = math.sin((_dotsController.value * 2 * math.pi) - delay);
        final double opacity = (value + 1) / 2;
        final double clampedOpacity = 0.3 + (opacity * 0.7);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8, height: 8,
          decoration: BoxDecoration(color: Colors.white.withOpacity(clampedOpacity), shape: BoxShape.circle),
        );
      },
    );
  }
}