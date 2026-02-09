import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/common/profile.dart';
import 'package:fyp/reportswork/report_detail_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  // Theme Colors
  final Color primaryColor = const Color(0xFF009688);
  final Color softBg = const Color(0xFFF0F4F4);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: softBg,
      body: Column(
        children: [
          // 1. Header
          _buildPatientHeader(user.uid),

          // 2. Reports List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('patientId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading data"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Sort: Latest First
                docs.sort((a, b) {
                  Timestamp t1 = a['date'] ?? Timestamp.now();
                  Timestamp t2 = b['date'] ?? Timestamp.now();
                  return t2.compareTo(t1);
                });

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSummaryCard(docs.length),
                    const SizedBox(height: 25),

                    const Text("My Medical Reports",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),

                    // Reports List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 15),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildReportCard(data);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- HEADER WITH FALLBACK CHECK ---
  Widget _buildPatientHeader(String uid) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 25, left: 24, right: 24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30)
        ),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: FutureBuilder<String>(
        // Use Helper Function for Name
        future: _fetchUserName(uid, isDoctor: false),
        builder: (context, snapshot) {
          String name = snapshot.data ?? "Patient";

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[200],
                  child: Icon(Icons.person, size: 30, color: primaryColor),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hello, $name",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text("Your Health Dashboard",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline, color: Colors.white, size: 20)
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.folder_shared_outlined, color: primaryColor),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("Total Reports Available", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  // --- REPORT CARD (UPDATED DOCTOR FETCH LOGIC) ---
  Widget _buildReportCard(Map<String, dynamic> data) {
    String dateStr = "Recent";
    if (data['formattedDate'] != null) {
      dateStr = data['formattedDate'];
    } else if (data['date'] != null) {
      DateTime d = (data['date'] as Timestamp).toDate();
      dateStr = "${d.day}/${d.month}/${d.year}";
    }

    // Doctor ID from report
    String doctorId = data['doctorId'] ?? "";

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportDetailScreen(reportData: data))
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Top Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_outlined, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Endoscopy Report",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1E))),
                      const SizedBox(height: 4),
                      Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),

            const Divider(height: 25),

            // --- FIXED DOCTOR NAME FETCHING ---
            FutureBuilder<String>(
              future: _fetchUserName(doctorId, isDoctor: true),
              builder: (context, snapshot) {
                String drName = "Fetching...";
                if (snapshot.connectionState == ConnectionState.done) {
                  drName = snapshot.data ?? "Unknown Doctor";
                }

                return Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Doctor: $drName",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doctorId.isNotEmpty)
                      Text(
                        "ID: ${doctorId.substring(0, 4)}...",
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }

  // --- HELPER FUNCTION: SMART FETCH ---
  // Ye function pehle specific collection check karega, agar wahan na mila to 'users' check karega
  Future<String> _fetchUserName(String uid, {required bool isDoctor}) async {
    if (uid.isEmpty) return "Unknown";

    try {
      // 1. Try Specific Collection First
      String collection = isDoctor ? 'doctors' : 'patients';
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();

      if (doc.exists) {
        return doc['name'] ?? (isDoctor ? "Dr. Unknown" : "Patient");
      }

      // 2. Fallback: Try 'users' collection (Old Data)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        return userDoc['name'] ?? "Unknown";
      }

    } catch (e) {
      debugPrint("Error fetching name for $uid: $e");
    }
    return "Unknown";
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_information_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("No Reports Yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 5),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Your medical reports from your doctor will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}