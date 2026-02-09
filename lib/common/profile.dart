import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Clipboard k liye zaroori ha
import 'package:fyp/main.dart'; // Global currentUser access

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- STATE ---
  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  // Colors
  final Color blue600 = const Color(0xFF2563EB); // Doctor Theme
  final Color teal600 = const Color(0xFF009688); // Patient Theme
  final Color red500 = const Color(0xFFEF4444);
  final Color textDark = const Color(0xFF1E293B);
  final Color textLight = const Color(0xFF64748B);
  final Color bgGrey = const Color(0xFFF8FAFC);
  final Color cardWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // --- 1. FETCH DATA & ROLE ---
  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Pehle 'users' collection check karein (Agar purana data hai)
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // Agar wahan nahi mila, to 'doctors' aur 'patients' check karein
        if (!doc.exists) {
          doc = await FirebaseFirestore.instance.collection('doctors').doc(user.uid).get();
          if (!doc.exists) {
            doc = await FirebaseFirestore.instance.collection('patients').doc(user.uid).get();
          }
        }

        if (mounted) {
          if (doc.exists) {
            setState(() {
              _data = doc.data() as Map<String, dynamic>;
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. LOGOUT ---
  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              currentUser = null; // Reset Global
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: red500, foregroundColor: Colors.white),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  // --- 3. COPY UID FUNCTION ---
  void _copyToClipboard(String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Patient ID copied to clipboard!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- 4. DELETE ACCOUNT ---
  Future<void> _handleDeleteAccount() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
        content: const Text("This action is permanent."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Users/Doctors/Patients sab se delete koshish karein
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
                  await FirebaseFirestore.instance.collection('patients').doc(user.uid).delete();
                  await FirebaseFirestore.instance.collection('doctors').doc(user.uid).delete();

                  await user.delete();
                  currentUser = null;
                  if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please re-login to delete account.")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: red500, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: bgGrey, body: Center(child: CircularProgressIndicator(color: blue600)));
    }

    // --- DATA EXTRACTION ---
    String role = _data['role'] ?? 'patient';
    bool isPatient = role == 'patient';
    Color themeColor = isPatient ? teal600 : blue600;

    String name = _data['name'] ?? "User";
    String email = _data['email'] ?? "N/A";
    String phone = _data['phone'] ?? "N/A";
    String uid = _data['uid'] ?? FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(onPressed: _handleLogout, icon: Icon(Icons.logout_rounded, color: red500)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // --- PROFILE HEADER ---
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeColor.withOpacity(0.1),
                    border: Border.all(color: themeColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "U",
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(name,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.bold)
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(role.toUpperCase(), style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 30),

                // --- UID CARD (FIXED OVERFLOW HERE) ---
                if (isPatient)
                  _buildUidCard(uid),

                const SizedBox(height: 20),
                _buildSectionTitle("CONTACT INFO"),
                const SizedBox(height: 10),
                _buildCard(Icons.email_outlined, "Email", email, themeColor),
                const SizedBox(height: 10),
                _buildCard(Icons.phone_outlined, "Phone", phone, themeColor),

                const SizedBox(height: 25),
                _buildSectionTitle(isPatient ? "PERSONAL DETAILS" : "PROFESSIONAL DETAILS"),
                const SizedBox(height: 10),

                // --- CONDITIONAL FIELDS ---
                if (isPatient) ...[
                  // PATIENT FIELDS
                  Row(
                    children: [
                      Expanded(child: _buildCard(Icons.cake_outlined, "Age", "${_data['age'] ?? 'N/A'} Yrs", themeColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCard(Icons.calendar_today_outlined, "DOB", _data['dob'] ?? 'N/A', themeColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildCard(Icons.badge_outlined, "CNIC", _data['cnic'] ?? 'N/A', themeColor),
                  const SizedBox(height: 10),
                  _buildCard(Icons.location_on_outlined, "Address", "${_data['city'] ?? ''}, ${_data['address'] ?? ''}", themeColor),
                ] else ...[
                  // DOCTOR FIELDS
                  _buildCard(Icons.science_outlined, "Specialty", _data['specialty'] ?? 'N/A', themeColor),
                  const SizedBox(height: 10),
                  _buildCard(Icons.local_hospital_outlined, "Hospital", _data['hospital'] ?? 'N/A', themeColor),
                  const SizedBox(height: 10),
                  _buildCard(Icons.verified_user_outlined, "License ID", _data['license'] ?? 'N/A', themeColor),
                ],

                const SizedBox(height: 40),

                // Delete Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _handleDeleteAccount,
                    icon: Icon(Icons.delete_forever, color: red500),
                    label: Text("Delete Account", style: TextStyle(color: red500)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: red500.withOpacity(0.3))),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // UPDATED UID CARD (Fixes Overflow & Adds Copy Button)
  Widget _buildUidCard(String uid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [teal600, teal600.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: teal600.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text("MY PATIENT UID", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 10),

          // --- FIXED ROW LAYOUT ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flexible lagaya hai taake text next line par chala jaye overflow ki bajaye
              Flexible(
                child: SelectableText(
                  uid,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // COPY BUTTON ADDED
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  onPressed: () => _copyToClipboard(uid),
                  icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                  tooltip: "Copy UID",
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              )
            ],
          ),
          const SizedBox(height: 5),
          const Text("Share this ID with your Doctor", style: TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildCard(IconData icon, String label, String value, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: textLight, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: textDark, fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}