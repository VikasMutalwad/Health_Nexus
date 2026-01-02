import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml: intl: ^0.19.0
import '../../models/user_session.dart';
import '../../models/patient_report.dart';

class DoctorDashboard extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const DoctorDashboard({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String _selectedFilter = 'pending_review';
  List<PatientReport> _reports = [];
  List<PatientReport> _filteredReports = [];
  int _pendingCount = 0;
  int _criticalCount = 0;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterReports);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterReports() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports = _reports.where((report) {
        return report.patientName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final pendingSnap = await FirebaseFirestore.instance.collection('diagnostic_reports').where('status', isEqualTo: 'pending_review').get();
      
      // Calculate critical cases client-side to avoid composite index error
      int criticals = 0;
      for (var doc in pendingSnap.docs) {
        final data = doc.data();
        if (data['results'] is Map && data['results']['Severity'] == 'High') {
          criticals++;
        }
      }

      // Remove orderBy to avoid composite index error, sort client-side instead
      Query query = FirebaseFirestore.instance.collection('diagnostic_reports');
      if (_selectedFilter != 'all') {
        query = query.where('status', isEqualTo: _selectedFilter);
      }
      final reportsSnap = await query.get();

      if (mounted) {
        setState(() {
          _pendingCount = pendingSnap.size;
          _criticalCount = criticals;
          _reports = reportsSnap.docs.map((doc) => PatientReport.fromFirestore(doc)).toList();
          _reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _filterReports();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Doctor Portal"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildReportsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            "Pending Review",
            _pendingCount,
            Colors.orange,
          ),
          _buildStatCard(
            "Critical Cases",
            _criticalCount,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search by patient name...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text("Pending Review"),
              selected: _selectedFilter == 'pending_review',
              onSelected: (val) {
                setState(() => _selectedFilter = 'pending_review');
                _loadData();
              },
              selectedColor: Colors.orange[200],
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text("Reviewed"),
              selected: _selectedFilter == 'reviewed',
              onSelected: (val) {
                setState(() => _selectedFilter = 'reviewed');
                _loadData();
              },
              selectedColor: Colors.green[200],
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text("All Reports"),
              selected: _selectedFilter == 'all',
              onSelected: (val) {
                setState(() => _selectedFilter = 'all');
                _loadData();
              },
              selectedColor: Colors.blue[200],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredReports.isEmpty) {
      return Center(child: Text("No reports found for this filter.", style: TextStyle(color: Colors.grey[600])));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredReports.length,
      itemBuilder: (context, index) {
        final report = _filteredReports[index];
        final severity = report.results['Severity'] ?? 'Low';
        Color statusColor = severity == 'High' ? Colors.red : (severity == 'Moderate' ? Colors.orange : Colors.green);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: statusColor.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(report.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(DateFormat('d MMM, h:mm a').format(report.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 16),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(color: Colors.black87, height: 1.5),
                    children: [
                      const TextSpan(text: "AI Diagnosis: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: "${report.results['Diagnosis'] ?? 'N/A'} "),
                      TextSpan(text: "($severity)", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                    const SizedBox(height: 8),
                    if (report.results.entries.any((e) => e.key != 'Diagnosis' && e.key != 'Severity'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Vitals & Details:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: report.results.entries
                                .where((e) => e.key != 'Diagnosis' && e.key != 'Severity')
                                .map((e) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 12)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (report.status == 'pending_review')
                      TextButton.icon(
                        onPressed: () => _markAsReviewed(report.id),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text("Mark Reviewed"),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text("Prescribe"),
                      onPressed: () => _showPrescriptionDialog(context, report),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrescriptionDialog(BuildContext context, PatientReport report) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.medical_services, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text("Rx: ${report.patientName}", style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter medicines & instructions:", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "e.g., Tab. Paracetamol 500mg BD...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.blue[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _sendPrescriptionToCloud(report, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Send to PHC"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPrescriptionToCloud(PatientReport report, String prescription) async {
    await FirebaseFirestore.instance.collection('prescriptions').add({
      'patientName': report.patientName,
      'prescription': prescription,
      'doctorName': widget.session.name,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending_dispense',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Prescription sent for ${report.patientName}")),
      );
    }
  }

  Future<void> _markAsReviewed(String reportId) async {
    await FirebaseFirestore.instance.collection('diagnostic_reports').doc(reportId).update({'status': 'reviewed'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report marked as reviewed."), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }
}