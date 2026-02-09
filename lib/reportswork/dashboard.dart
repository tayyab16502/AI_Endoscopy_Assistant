import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/reportswork/report_history.dart';
import 'package:fyp/common/profile.dart';
import 'report_detail_screen.dart';
// Note: Ensure route names in main.dart are correct

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';

  final Color primaryDark = const Color(0xFF1A1C1E);
  final Color accentBlue = const Color(0xFF007AFF);
  final Color softBg = const Color(0xFFF2F2F7);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // Safety Check
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: softBg,
      body: Column(
        children: [
          // Header (Updated to fetch from 'users')
          _buildCompactHeader(user.uid),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('doctorId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading reports"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;

                // Sorting: Latest first
                allDocs.sort((a, b) {
                  var adate = a['date'] as Timestamp?;
                  var bdate = b['date'] as Timestamp?;
                  if (adate == null || bdate == null) return 0;
                  return bdate.compareTo(adate);
                });

                // Stats Calculation
                int total = allDocs.length;
                int patients = allDocs.map((e) => e['patientName']).toSet().length;
                int pending = allDocs.where((e) => e['status'] == 'pending').length;
                int completed = allDocs.where((e) => e['status'] == 'completed').length;

                // Search & Filter Logic
                final filteredDocs = allDocs.where((doc) {
                  String name = (doc['patientName'] ?? '').toString().toLowerCase();
                  String status = (doc['status'] ?? 'pending').toString().toLowerCase();
                  bool matchesSearch = name.contains(_searchQuery.toLowerCase());
                  bool matchesFilter = _filterStatus == 'all' || status == _filterStatus;
                  return matchesSearch && matchesFilter;
                }).toList();

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  children: [
                    _buildCompactStatsRow(total, patients, completed, pending),
                    const SizedBox(height: 25),
                    _buildMinimalSearch(),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Recent Activity",
                            style: TextStyle(color: primaryDark, fontSize: 17, fontWeight: FontWeight.w700)),
                        GestureDetector(
                          onTap: _navigateToHistory,
                          child: Text("See History",
                              style: TextStyle(color: accentBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Report List
                    _buildDenseReportList(filteredDocs),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNewReport,
        backgroundColor: primaryDark,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _navigateToNewReport() {
    Navigator.pushNamed(context, '/new_report');
  }

  // --- UPDATED HEADER LOGIC (FETCH FROM 'users') ---
  Widget _buildCompactHeader(String uid) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 15, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: FutureBuilder<DocumentSnapshot>(
        // Change: 'doctors' ki jagah 'users' collection use kar rahe hain
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, userSnapshot) {
          String doctorName = "Doctor"; // Default Placeholder

          if (userSnapshot.connectionState == ConnectionState.done) {
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              // Data mil gaya -> Name update karein
              doctorName = userSnapshot.data!['name'] ?? "Doctor";
            }
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Dr. $doctorName",
                      style: TextStyle(color: primaryDark, fontSize: 19, fontWeight: FontWeight.w800)),
                  Text("Dashboard Overview", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
              IconButton(
                onPressed: _navigateToProfile,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: softBg, shape: BoxShape.circle),
                  child: Icon(Icons.person_outline, color: primaryDark, size: 20),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  // --- STATS WIDGETS ---
  Widget _buildCompactStatsRow(int total, int patients, int comp, int pend) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.3,
      children: [
        _miniStatCard("Reports", total.toString(), Icons.analytics_rounded, Colors.blue),
        _miniStatCard("Patients", patients.toString(), Icons.people_rounded, Colors.teal),
        _miniStatCard("Finished", comp.toString(), Icons.check_circle_rounded, Colors.orange),
        _miniStatCard("Pending", pend.toString(), Icons.access_time_filled_rounded, Colors.redAccent),
      ],
    );
  }

  Widget _miniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primaryDark)),
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalSearch() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "Search patient name...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: PopupMenuButton<String>(
            icon: Icon(Icons.tune_rounded, color: accentBlue, size: 20),
            onSelected: (v) => setState(() => _filterStatus = v),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text("All Activity")),
              const PopupMenuItem(value: 'completed', child: Text("Completed")),
              const PopupMenuItem(value: 'pending', child: Text("Pending")),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // --- REPORT LIST (With Overflow Protection) ---
  Widget _buildDenseReportList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        child: Center(child: Text("No records found", style: TextStyle(color: Colors.grey[400]))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;

        String pName = data['patientName'] ?? 'Unknown';
        String pId = data['patientId'] ?? 'ID: --';
        String status = (data['status'] ?? 'pending').toString().toUpperCase();
        bool isDone = status == 'COMPLETED';

        String dateStr = "Recent";
        if (data['date'] != null) {
          DateTime d = (data['date'] as Timestamp).toDate();
          dateStr = "${d.day}/${d.month}/${d.year}";
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ReportDetailScreen(reportData: data)
                )
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Fixed Overflow for ID
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "ID: $pId",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDone ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      child: Icon(Icons.person, color: isDone ? Colors.green : Colors.orange),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(isDone ? Icons.check_circle : Icons.pending,
                                  size: 14,
                                  color: isDone ? Colors.green : Colors.orange
                              ),
                              const SizedBox(width: 4),
                              Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDone ? Colors.green : Colors.orange)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToHistory() => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportHistoryScreen()));
  void _navigateToProfile() => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
}