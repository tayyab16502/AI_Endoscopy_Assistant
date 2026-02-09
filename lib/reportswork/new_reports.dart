import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/reportswork/upload_video.dart'; // Ensure correct path

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  // --- CONTROLLERS ---
  final _searchController = TextEditingController();

  // --- STATE ---
  Map<String, dynamic>? _foundPatient;
  bool _isLoading = false;
  String _message = "";

  // --- COLORS ---
  final Color primaryColor = const Color(0xFF2563EB);
  final Color backgroundColor = const Color(0xFFF8FAFC);
  final Color surfaceColor = Colors.white;
  final Color textDark = const Color(0xFF1E293B);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. SEARCH LOGIC ---
  Future<void> _handleSearch() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _message = "Please enter an Email or Patient UID");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = "";
      _foundPatient = null;
    });

    try {
      // Step A: Search by Email first
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where('email', isEqualTo: query)
          .limit(1)
          .get();

      // Step B: If not found by Email, try searching by UID
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .where('uid', isEqualTo: query)
            .limit(1)
            .get();
      }

      // Step C: Update UI
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data() as Map<String, dynamic>;

        // Zaroori: ID ko explicitly set karein taake agay link ho sakay
        data['id'] = snapshot.docs.first['uid'];

        setState(() {
          _foundPatient = data;
        });
      } else {
        setState(() {
          _message = "No patient found. Please check the Email or UID.";
        });
      }
    } catch (e) {
      setState(() => _message = "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 2. NEXT STEP (Go to Upload) ---
  void _handleNext() {
    if (_foundPatient != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          // Fetch kiya hua data agli screen ko pass karein
          builder: (context) => UploadVideoScreen(patientData: _foundPatient!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Find Patient", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Search Patient Record", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 8),
              const Text("Enter Patient's Email or UID to fetch details from database.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),

              // --- SEARCH BOX ---
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: "Email or UID",
                        hintText: "e.g. patient@mail.com",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Search Database", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- FEEDBACK MESSAGES ---
              if (_message.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                    child: Text(_message, style: const TextStyle(color: Colors.red)),
                  ),
                ),

              // --- RESULT CARD (If Patient Found) ---
              if (_foundPatient != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Patient Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 12),
                    _buildPatientDetailsCard(),
                    const SizedBox(height: 30),

                    // Proceed Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Confirm & Upload Video", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.video_call_rounded, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER: Display Fetched Data ---
  Widget _buildPatientDetailsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: primaryColor.withOpacity(0.1),
            child: Icon(Icons.person, size: 40, color: primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            _foundPatient!['name'] ?? 'Unknown Name',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
            child: Text("ID: ${_foundPatient!['id']}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 30),

          _buildInfoRow(Icons.email_outlined, "Email", _foundPatient!['email']),
          _buildInfoRow(Icons.phone_outlined, "Phone", _foundPatient!['phone']),
          _buildInfoRow(Icons.cake_outlined, "Age / DOB", "${_foundPatient!['age'] ?? 'N/A'} Yrs / ${_foundPatient!['dob'] ?? 'N/A'}"),
          _buildInfoRow(Icons.badge_outlined, "CNIC", _foundPatient!['cnic']),
          _buildInfoRow(Icons.location_on_outlined, "Address", "${_foundPatient!['city'] ?? ''}, ${_foundPatient!['address'] ?? ''}"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                Text(value ?? "N/A", style: TextStyle(fontSize: 14, color: textDark, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}