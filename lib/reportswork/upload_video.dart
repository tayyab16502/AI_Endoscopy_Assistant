import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Note: Apne Dashboard screen ka sahi file path import karein
// import 'package:your_app/screens/doctor_dashboard.dart';

class UploadVideoScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;
  const UploadVideoScreen({super.key, required this.patientData});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  bool _isProcessing = false;
  String _statusMessage = "";
  String? _errorMessage;

  final String baseUrl = "https://lathiest-diego-crablike.ngrok-free.dev";

  Future<void> _pickAndProcessVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _uploadVideoDirectly(File(video.path));
    }
  }

  Future<void> _uploadVideoDirectly(File videoFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = "Please login first.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = "Preparing Video for Upload...";
    });

    try {
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('dd-MM-yyyy at h:mm a').format(now);

      setState(() {
        _statusMessage = "Uploading Original Video to AI Server...\n(Please wait, do not close app)";
      });

      var uri = Uri.parse('$baseUrl/analyze_video');
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        "ngrok-skip-browser-warning": "true",
        "Connection": "Keep-Alive",
      });

      request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));

      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw "Timeout: Upload took too long. Internet slow ho sakta hai.";
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String finalReport = data['report_text'];

        await FirebaseFirestore.instance.collection('reports').add({
          'doctorId': user.uid,
          'patientName': widget.patientData['name'],
          'patientId': widget.patientData['id'],
          'reportText': finalReport,
          'date': FieldValue.serverTimestamp(),
          'formattedDate': formattedDate,
          'status': 'completed',
        });

        setState(() {
          _isProcessing = false;
        });

        _showReportDialog(finalReport, formattedDate);
      } else {
        throw "Server Error: ${response.statusCode}\nDetails: ${response.body}";
      }

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = "Error: $e";
      });
    }
  }

  void _showReportDialog(String report, String displayDate) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // User bahar click karke band na kar sake
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("AI Diagnosis Report", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 5),
            Text(displayDate, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Text(report, style: const TextStyle(fontSize: 16, height: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // --- REDIRECTION LOGIC ---
                  // Sabse pehle dialog ko close karein
                  Navigator.pop(context);

                  // Phir Dashboard par bhej dein aur pichli saari screens remove kar dein
                  // Agar aapne routes define kiye hain to: Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                  // Warna direct screen call:
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Done", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Procedure Check")),
      body: Center(
        child: _isProcessing
            ? _buildLoadingView()
            : _errorMessage != null
            ? _buildErrorView()
            : _buildUploadView(),
      ),
    );
  }

  // UI Helpers unchanged...
  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(strokeWidth: 6, color: Colors.blueAccent),
        const SizedBox(height: 40),
        Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _pickAndProcessVideo, child: const Text("Try Again")),
        ],
      ),
    );
  }

  Widget _buildUploadView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.blueAccent),
        const SizedBox(height: 20),
        const Text("Upload Video for Analysis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _pickAndProcessVideo,
          child: const Text("Select Video"),
        ),
      ],
    );
  }
}