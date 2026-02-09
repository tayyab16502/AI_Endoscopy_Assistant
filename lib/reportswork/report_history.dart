import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  // --- STATE ---
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _dateFilter = 'all';
  bool _showFilters = false;

  // Colors
  final Color blue600 = const Color(0xFF2563EB);
  final Color green500 = const Color(0xFF22C55E);
  final Color orange500 = const Color(0xFFF97316);
  final Color bgBlue50 = const Color(0xFFEFF6FF);
  final Color bgIndigo50 = const Color(0xFFEEF2FF);

  // --- ACTIONS ---
  Future<void> _handleDelete(String docId) async {
    bool confirm = await _showDeleteConfirmDialog();
    if (confirm) {
      await FirebaseFirestore.instance.collection('reports').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report deleted successfully")));
      }
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Report"),
        content: const Text("Are you sure you want to delete this report permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgBlue50, Colors.white, bgIndigo50],
          ),
        ),
        child: Column(
          children: [
            // 1. Header
            _buildHeader(),

            // 2. Main Content with StreamBuilder
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error loading data"));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs;

                  // --- APPLY FILTER LOGIC ---
                  final filteredList = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Search Logic
                    String name = (data['patientName'] ?? '').toString().toLowerCase();
                    String diag = (data['diagnosis'] ?? '').toString().toLowerCase();
                    bool matchesSearch = name.contains(_searchQuery.toLowerCase()) || diag.contains(_searchQuery.toLowerCase());

                    // Status Logic
                    bool matchesStatus = _statusFilter == 'all' || (data['status'] ?? '') == _statusFilter;

                    // Date Logic
                    bool matchesDate = true;
                    if (_dateFilter != 'all' && data['date'] != null) {
                      DateTime reportDate = (data['date'] as Timestamp).toDate();
                      final now = DateTime.now();
                      final diff = now.difference(reportDate).inDays;
                      if (_dateFilter == 'today') matchesDate = diff == 0;
                      else if (_dateFilter == 'week') matchesDate = diff <= 7;
                      else if (_dateFilter == 'month') matchesDate = diff <= 30;
                    }

                    return matchesSearch && matchesStatus && matchesDate;
                  }).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterSection(),
                        const SizedBox(height: 16),
                        Text(
                          "Showing ${filteredList.length} reports",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _buildReportsList(filteredList),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 16, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text("Dashboard", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Text("Report History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search patient name...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    filled: true, fillColor: Colors.grey[50],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, color: blue600),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDropdown("Status", _statusFilter, ['all', 'completed', 'pending'], (val) => setState(() => _statusFilter = val!))),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown("Date", _dateFilter, ['all', 'today', 'week', 'month'], (val) => setState(() => _dateFilter = val!))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsList(List<QueryDocumentSnapshot> reports) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.folder_open, size: 60, color: Colors.grey[300]),
            const Text("No matching reports found"),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final data = reports[index].data() as Map<String, dynamic>;
        final docId = reports[index].id;
        final isCompleted = (data['status'] ?? 'pending') == 'completed';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(data['patientName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? green500 : orange500,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(data['status'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("${data['age'] ?? 'N/A'} Years • ${data['gender'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              Text(data['diagnosis'] ?? 'No Diagnosis available', style: const TextStyle(fontSize: 14)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data['date'] != null ? DateFormat('dd MMM yyyy').format((data['date'] as Timestamp).toDate()) : '',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.remove_red_eye_outlined, size: 20), onPressed: () => _viewReport(data['reportText'])),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _handleDelete(docId)),
                    ],
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _viewReport(String? text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(child: Text(text ?? "No report text available")),
      ),
    );
  }
}