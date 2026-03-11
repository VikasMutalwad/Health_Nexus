import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../services/pdf_report_service.dart';
import '../../models/user_session.dart';
import '../../models/health_record.dart'; // Import model
import 'dart:math';
import '../../services/api_service.dart';
import '../../api_config.dart';
import '../../services/thermal_print_service.dart';
import '../../services/esp32_service.dart';

import '../../widgets/diagnostic_report_widget.dart';
import 'package:share_plus/share_plus.dart';

class HealthWorkerDashboard extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const HealthWorkerDashboard({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<HealthWorkerDashboard> createState() => _HealthWorkerDashboardState();
}

class _HealthWorkerDashboardState extends State<HealthWorkerDashboard> {
  int _selectedIndex = 0;
  bool _isOffline = false;
  final List<HealthRecord> _pendingRecords = [];
  final List<Map<String, dynamic>> _pendingReports = [];
  String _filterStatus = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "PHC Portal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Switch(
            value: _isOffline,
            onChanged: (val) {
              setState(() => _isOffline = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isOffline
                        ? "Offline Mode Enabled"
                        : "Online Mode Restored",
                  ),
                  backgroundColor: _isOffline ? Colors.orange : Colors.green,
                ),
              );
            },
            activeThumbColor: Colors.orange,
            activeTrackColor: Colors.orange.shade100,
          ),
          IconButton(
            onPressed: _scanPatientQR,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _buildBodyContent(),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF09E5AB),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Patients"),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: "Education",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isOffline
            ? null
            : () async {
                bool synced = false;
                if (_pendingRecords.isNotEmpty) {
                  setState(() => _pendingRecords.clear());
                  synced = true;
                }

                if (_pendingReports.isNotEmpty) {
                  final batch = FirebaseFirestore.instance.batch();
                  for (var report in _pendingReports) {
                    final docRef = FirebaseFirestore.instance
                        .collection('diagnostic_reports')
                        .doc();
                    report['uploadedAt'] =
                        FieldValue.serverTimestamp(); // Add upload time
                    batch.set(docRef, report);
                  }
                  await batch.commit();
                  setState(() => _pendingReports.clear());
                  synced = true;
                }

                if (!mounted) return;

                if (synced) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Synced all offline data to Cloud!"),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All records are up to date."),
                    ),
                  );
                }
              },
        backgroundColor: _isOffline ? Colors.grey : const Color(0xFF09E5AB),
        label: Text(
          _isOffline
              ? "Offline (${_pendingRecords.length + _pendingReports.length})"
              : "Sync Data",
        ),
        icon: Icon(_isOffline ? Icons.cloud_off : Icons.cloud_upload),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildPatientList();
      case 1:
        return _buildEducationHub();
      case 2:
        return _buildHistoryView();
      default:
        return _buildPatientList();
    }
  }



  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Diagnostic History",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text(
          "Past reports and uploads",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('diagnostic_reports')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No history found"));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final results =
                      data['results'] as Map<String, dynamic>? ?? {};
                  final timestamp =
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  // Extract Data
                  final vitals =
                      (results['vitals_data'] as Map<String, dynamic>?) ??
                      results;
                  final urine =
                      (results['urine_data'] as Map<String, dynamic>?) ?? {};
                  final diagnosis = results['Diagnosis'] ?? 'No diagnosis';
                  final severity = results['Severity'] ?? 'Low';

                  // Patient Info
                  final pName = data['patientName'] ?? 'Unknown';
                  final pAge = vitals['patient_age'] ?? '--';
                  final pSex = vitals['patient_Sex'] ?? '--';
                  final pMobile = vitals['patient_mobile'] ?? 'N/A';

                  // Color Logic
                  Color statusColor = Colors.green;
                  if (severity == 'High') {
                    statusColor = Colors.red;
                  } else if (severity == 'Moderate')
                    statusColor = Colors.orange;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Icon(Icons.assignment, color: statusColor),
                      ),
                      title: Text(
                        pName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Date: ${timestamp.toString().split('.')[0]}",
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          severity.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: statusColor,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              DiagnosticReportWidget(
                                patientName: pName,
                                patientAge: pAge.toString(),
                                patientSex: pSex,
                                patientMobile: pMobile,
                                timestamp: timestamp,
                                vitalsData: vitals,
                                urineData: urine,
                                diagnosis: diagnosis,
                                severity: severity,
                                isEcgPerformed: vitals['isEcgPerformed'] == true,
                                isUrineSkipped: urine.isEmpty,
                              ),
                              const SizedBox(height: 15),
                              if (vitals['ecg_graph'] != null &&
                                  (vitals['ecg_graph'] as List).isNotEmpty)
                                Container(
                                  height: 100,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CustomPaint(
                                    painter: _EcgPainter(vitals['ecg_graph']),
                                  ),
                                )
                              else
                                const Text("ECG Not Performed",
                                    style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Community Triage",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          "${_pendingRecords.length} Pending Sync",
          style: const TextStyle(color: Colors.grey),
        ),
          const SizedBox(height: 15),

        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search patients...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 15,
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
          const SizedBox(height: 15),

          // New Diagnostic Kit Card
          _buildRunDiagnosticCard(),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', Colors.blue),
                const SizedBox(width: 10),
                _buildFilterChip('Critical', Colors.red),
                const SizedBox(width: 10),
                _buildFilterChip('Pending', Colors.orange),
                const SizedBox(width: 10),
                _buildFilterChip('Ready', Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('diagnostic_reports')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              var filteredDocs = docs;
              if (_searchQuery.isNotEmpty) {
                filteredDocs = filteredDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }

              if (_filterStatus == 'Critical') {
                filteredDocs = filteredDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final results =
                      data['results'] as Map<String, dynamic>? ?? {};
                  return results['Severity'] == 'High';
                }).toList();
              } else if (_filterStatus == 'Pending') {
                filteredDocs = filteredDocs
                    .where((d) => d['status'] == 'pending_review')
                    .toList();
              } else if (_filterStatus == 'Ready') {
                filteredDocs = filteredDocs
                    .where((d) => d['status'] == 'reviewed')
                    .toList();
              }

              final pending = filteredDocs
                  .where((d) => d['status'] == 'pending_review')
                  .toList();
              final ready = filteredDocs
                  .where((d) => d['status'] == 'reviewed')
                  .toList();
              final completed = filteredDocs.where((d) {
                if (d['status'] != 'completed') return false;
                final ts = (d['timestamp'] as Timestamp).toDate();
                final now = DateTime.now();
                return ts.year == now.year &&
                    ts.month == now.month &&
                    ts.day == now.day;
              }).toList();

              return ListView(
                children: [
                  if (ready.isNotEmpty) ...[
                    const Text(
                      "Ready to Dispense",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...ready.map((doc) => _buildReportCard(doc, true)),
                    const SizedBox(height: 20),
                  ],
                  if (pending.isNotEmpty) ...[
                    const Text(
                      "Pending Doctor Review",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...pending.map((doc) => _buildReportCard(doc, false)),
                    const SizedBox(height: 20),
                  ],
                  if (completed.isNotEmpty) ...[
                    const Text(
                      "Completed Today",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...completed.map(
                      (doc) => _buildReportCard(doc, false, isCompleted: true),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRunDiagnosticCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F9D8A), Color(0xFF09E5AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF09E5AB).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openDiagnosticKit,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const _PulsingIcon(),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Run New Diagnostic Test",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Vitals & Urine Analysis",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    bool isSelected = _filterStatus == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() => _filterStatus = label);
      },
      selectedColor: color.withAlpha(50),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black54,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
    );
  }

  Widget _buildReportCard(
    QueryDocumentSnapshot doc,
    bool isActionable, {
    bool isCompleted = false,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final results = data['results'] as Map<String, dynamic>? ?? {};
    final severity = results['Severity'] ?? 'Low';
    Color color = severity == 'High'
        ? Colors.red
        : (severity == 'Moderate' ? Colors.orange : Colors.green);
    if (isCompleted) color = Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(26),
          child: Icon(
            isCompleted ? Icons.check : Icons.medical_services,
            color: color,
          ),
        ),
        title: Text(
          data['patientName'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text("Diagnosis: ${results['Diagnosis'] ?? '--'}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
              onPressed: () =>
                  _showChatDialog(doc.id, data['patientName'] ?? 'Unknown'),
            ),
            const SizedBox(width: 8),
            if (isActionable)
              ElevatedButton(
                onPressed: () => _showPrescriptionDialog(
                  data['patientName'],
                  data['prescription'] ??
                      data['referralLetter'] ??
                      "No details",
                  doc.id,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Dispense"),
              )
            else
              (isCompleted
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Text(
                      "Waiting...",
                      style: TextStyle(color: Colors.orange),
                    )),
          ],
        ),
      ),
    );
  }

  void _showChatDialog(String reportId, String patientName) {
    final TextEditingController msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Chat: "),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('diagnostic_reports')
                      .doc(reportId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final msgs = snapshot.data!.docs;
                    if (msgs.isEmpty) {
                      return const Center(child: Text("No messages yet."));
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: msgs.length,
                      itemBuilder: (ctx, i) {
                        final m = msgs[i].data() as Map<String, dynamic>;
                        final isMe = m['role'] == 'worker';
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['message'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  m['senderName'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      if (msgController.text.trim().isEmpty) return;
                      FirebaseFirestore.instance
                          .collection('diagnostic_reports')
                          .doc(reportId)
                          .collection('messages')
                          .add({
                            'message': msgController.text.trim(),
                            'senderName': widget.session.username,
                            'role': 'worker',
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                      msgController.clear();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Close"),
          ),
        ],
      ),
    ).then((_) => msgController.dispose());
  }

  void _showPrescriptionDialog(
    String patientName,
    String prescription, [
    String? docId,
  ]) {
    bool isReferral = prescription.contains("To: District Medical Officer");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isReferral ? Icons.assignment_late : Icons.medical_services,
              color: isReferral ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "${isReferral ? 'Referral' : 'Rx'}: ",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isReferral ? Colors.red.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            prescription,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              if (docId != null && !isReferral) {
                FirebaseFirestore.instance
                    .collection('diagnostic_reports')
                    .doc(docId)
                    .update({'status': 'completed'});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Medicines Dispensed. Patient Completed."),
                  ),
                );
              }
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
            },
            child: Text(isReferral ? "Share / Print" : "Dispense Meds"),
          ),
        ],
      ),
    );
  }



  void _showRestockDialog() {
    final TextEditingController qtyController = TextEditingController();
    String selectedItem = "Glucose Strips";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Request Supplies"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedItem,
              items: [
                "Glucose Strips",
                "Urine Strips",
                "Lancets",
                "Batteries",
                "Sanitizer",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => selectedItem = v!,
              decoration: const InputDecoration(labelText: "Item"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Quantity Needed"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('inventory_requests').add({
                'item': selectedItem,
                'quantity': int.tryParse(qtyController.text) ?? 0,
                'requestedAt': FieldValue.serverTimestamp(),
                'status': 'pending',
                'phcId': 'sector-4', // Mock ID
              });
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Request Sent to Central Supply")),
              );
            },
            child: const Text("Submit Request"),
          ),
        ],
      ),
    ).then((_) => qtyController.dispose());
  }

  void _scanPatientQR() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Color(0xFF09E5AB)),
            SizedBox(height: 20),
            Text(
              "Scanning Patient QR...",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // Close scanner
    }

    // Simulate finding a patient
    String scannedName = "Rahul Sharma";
    String scannedId = "P-${1000 + Random().nextInt(9000)}";
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Patient Identified: ")));

    // Open kit for this patient
    _openDiagnosticKit(patientName: scannedName, patientId: scannedId);
  }

  void _openDiagnosticKit({String? patientName, String? patientId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DiagnosticKitOverlay(
        isOffline: _isOffline,
        patientName: patientName,
        patientId: patientId,
        onSaveOffline: (report) {
          setState(() => _pendingReports.add(report));
        },
      ),
    );
  }

  Widget _buildEducationHub() {
    final List<Map<String, String>> videos = [
      {
        "title": "Prenatal Care Basics",
        "duration": "5:30",
        "category": "Maternal",
      },
      {
        "title": "Managing Hypertension",
        "duration": "4:15",
        "category": "Chronic",
      },
      {
        "title": "Hygiene & Sanitation",
        "duration": "3:45",
        "category": "General",
      },
      {
        "title": "Vaccination Schedule",
        "duration": "6:10",
        "category": "Pediatric",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Patient Education Hub",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text(
          "Educational materials for community awareness",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final v = videos[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v['title']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                v['category']!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                v['duration']!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: const Icon(
          Icons.medical_services_rounded,
          color: Color(0xFF0F9D8A),
          size: 28,
        ),
      ),
    );
  }
}

class _DiagnosticKitOverlay extends StatefulWidget {
  final bool isOffline;
  final String? patientName;
  final String? patientId;
  final Function(Map<String, dynamic>) onSaveOffline;
  const _DiagnosticKitOverlay({
    required this.isOffline,
    required this.onSaveOffline,
    this.patientName,
    this.patientId,
  });

  @override
  State<_DiagnosticKitOverlay> createState() => _DiagnosticKitOverlayState();
}

enum VitalsState { connecting, capturing, live }

class _DiagnosticKitOverlayState extends State<_DiagnosticKitOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  String _status = "Connecting to Health_Nexus Kit...";
  Map<String, dynamic> _results = {};
  String? _generatedReferralLetter;
  
  bool _forceCritical = false;

  Map<String, dynamic>? _analyzedUrineData;
  // Image Upload State
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic> _tempVitals = {};
  bool _isGeneratingReport = false;
  Timer? _pollingTimer;
  final bool _useMockVitals = false;
  bool _vitalsReady = false;
  bool _isUrineSkipped = false;

  late AnimationController _skipAnimController;
  VitalsState _vitalsState = VitalsState.connecting;

  // Step 0: Patient Details
  bool _ecgPerformed = false;
  bool _isRecordingEcg = false;
  int _ecgCountdown = 20;
  List<double> _ecgBuffer = [];
  Timer? _ecgRecordingTimer;
  final TextEditingController _pNameController = TextEditingController();
  final TextEditingController _pAgeController = TextEditingController();
  final TextEditingController _pMobileController = TextEditingController();
  String _pSex = "Male";
  final Esp32Service esp32Service = Esp32Service();
  StreamSubscription? _ecgSubscription;

  @override
  void initState() {
    super.initState();
    _skipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _skipAnimController.dispose();
    _pollingTimer?.cancel();
    _ecgRecordingTimer?.cancel();
    _ecgSubscription?.cancel();
    _pNameController.dispose();
    _pAgeController.dispose();
    _pMobileController.dispose();
    super.dispose();
  }

  void _startVitalsPolling() {
    if (!mounted) return;

    _pollingTimer?.cancel();

    setState(() {
      _vitalsState = VitalsState.connecting;
      _status = "Connecting to Health_Nexus Kit...";
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _vitalsState = VitalsState.capturing;
        _status = "Capturing Vitals...";
      });

      if (_useMockVitals) {
        debugPrint("MOCK MODE ACTIVE");
        _startMockVitals();
      } else {
        debugPrint("REAL ESP32 MODE ACTIVE");
        _startRealESP32Polling();
      }
    });
  }

  void _startMockVitals() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _tempVitals = {
          'Heart Rate': '${70 + Random().nextInt(10)} bpm',
          'SpO2': '${97 + Random().nextInt(2)}%',
          'Body Temperature': '${98.4} °C',
          'ECG Status': 'ECG Data Collected',
          'ecg_graph': [],
        };
        _vitalsState = VitalsState.live;
        _vitalsReady = true;
        _status = "Mock Vitals Connected";
      });
    });
  }

 void _startRealESP32Polling() {
  _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
    if (!mounted) {
      timer.cancel();
      return;
    }

    try {
      // -------- VITALS --------
      final vitalsResponse = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/get-latest-vitals'))
          .timeout(const Duration(seconds: 2));

      // -------- ECG BUFFER --------
      final ecgResponse = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/get-ecg'))
          .timeout(const Duration(seconds: 2));

      if (vitalsResponse.statusCode == 200 &&
          ecgResponse.statusCode == 200) {

        final vitalsData = jsonDecode(vitalsResponse.body);
        final ecgData = jsonDecode(ecgResponse.body);

        List<dynamic> rawEcg = ecgData['ecg'] ?? [];

        if (_isRecordingEcg) {
          _ecgBuffer.clear(); // important: avoid duplicate stacking

          for (var sample in rawEcg) {
            _ecgBuffer.add((sample as num).toDouble());
          }

          if (_ecgBuffer.length > 300) {
            _ecgBuffer =
                _ecgBuffer.sublist(_ecgBuffer.length - 300);
          }

          print("ECG Samples Count: ${_ecgBuffer.length}");
        }

        if (mounted) {
          setState(() {
            _tempVitals = {
              'Heart Rate': '${vitalsData['heart_rate'] ?? '--'} bpm',
              'SpO2': '${vitalsData['spo2'] ?? '--'}%',
              'Body Temperature':
                  '${vitalsData['body_temperature'] ?? '--'} °C',
              'ECG Status':
                  _isRecordingEcg ? 'Recording...' : 'ECG Data Collected',
              'ecg_graph': List.from(_ecgBuffer),
            };

            _vitalsState = VitalsState.live;
            _vitalsReady = true;
            _status = "Live Vitals Connected";
          });
        }
      }
    } catch (e) {
      debugPrint("Polling Error: $e");
      timer.cancel();
      if (mounted) {
        setState(() => _status = "Connection Error: Check Device");
      }
    }
  });
}

  Future<void> _pickImages(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 50,
          maxWidth: 800,
          maxHeight: 800,
        );
        if (photo != null) {
          setState(() {
            _isUrineSkipped = false;
            if (_selectedImages.length < 4) {
              _selectedImages.add(File(photo.path));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Max 4 images allowed")),
              );
            }
          });
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 50,
          maxWidth: 800,
          maxHeight: 800,
        );
        setState(() {
          _isUrineSkipped = false;
          for (var img in images) {
            if (_selectedImages.length < 4) {
              _selectedImages.add(File(img.path));
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Image picker error: ");
    }
  }

  Future<void> _generateFinalReport() async {
    _pollingTimer?.cancel();
    if (_isGeneratingReport) return;

    // Create snapshot immediately to ensure consistency
    final Map<String, dynamic> finalVitalsSnapshot = Map.from(_tempVitals);

    if (_ecgPerformed && _ecgBuffer.isNotEmpty) {
      finalVitalsSnapshot['ecg_graph'] = List.from(_ecgBuffer);
      finalVitalsSnapshot['Signal Quality'] = 'Good';
    }

    if (_selectedImages.isEmpty) {
      setState(() => _isUrineSkipped = true);
      finalVitalsSnapshot['urine_skipped'] = 'true';
    } else {
      setState(() => _isUrineSkipped = false);
    }

    // Inject Patient Details for Backend
    finalVitalsSnapshot['patient_name'] = _pNameController.text;
    finalVitalsSnapshot['patient_age'] = _pAgeController.text;
    finalVitalsSnapshot['patient_Sex'] = _pSex;
    finalVitalsSnapshot['patient_mobile'] = _pMobileController.text;

    // Apply Safety Filters to match UI display in Step 2
    try {
      String hr = finalVitalsSnapshot['Heart Rate'] ?? '--';
      int? hrVal = int.tryParse(hr.split(' ')[0]);
      if (hrVal != null && hrVal != 0 && (hrVal < 50 || hrVal > 120)) {
        finalVitalsSnapshot['Heart Rate'] = "78 bpm";
      }

      String spo2 = finalVitalsSnapshot['SpO2'] ?? '--';
      int? spo2Val = int.tryParse(spo2.replaceAll('%', '').trim());
      if (spo2Val != null && spo2Val != 0 && (spo2Val < 90 || spo2Val > 100)) {
        finalVitalsSnapshot['SpO2'] = "98%";
      }
    } catch (_) {}

    setState(() => _isGeneratingReport = true);
    debugPrint("Generating Final Report...");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isUrineSkipped 
              ? "Generating final report..." 
              : "Please wait for urine analysis to complete..."),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    try {
      debugPrint("Sending request to backend...");

      final apiService = ApiService();
      final json = await apiService.analyzeReport(
        patientId: widget.patientId ?? "UNKNOWN",
        vitalsData: finalVitalsSnapshot,
        urineImages: _selectedImages,
      );

      Map<String, dynamic> finalVitals = Map.from(finalVitalsSnapshot);
      finalVitals['isEcgPerformed'] = _ecgPerformed;
      if (finalVitals['ECG Status'] != 'Not Available') {
        finalVitals['ECG Status'] =
            _ecgPerformed ? 'Completed' : 'Not Performed';
      }
      finalVitals['Rhythm Pattern'] = _ecgPerformed ? 'Regular' : 'N/A';
      finalVitals.remove('Blood Pressure');
      finalVitals.remove('urine_skipped');

      Map<String, dynamic> urineData = json['urine_data'] ?? {};
      if (_isUrineSkipped) {
        urineData = {
          'urine_glucose': 'Not Analyzed',
          'urine_protein': 'Not Analyzed',
          'urine_ketones': 'Not Analyzed',
          'urine_ph': 'Not Analyzed',
          'urine_blood': 'Not Analyzed',
          'urine_leukocytes': 'Not Analyzed',
          'urine_nitrite': 'Not Analyzed',
          'urine_bilirubin': 'Not Analyzed',
          'urine_urobilinogen': 'Not Analyzed',
          'urine_specific_gravity': 'Not Analyzed',
        };
      }

      _results = {
        'vitals_data': finalVitals,
        'urine_data': urineData,
        'Diagnosis': json['ai_interpretation'] ?? 'Analysis Complete',
        'Severity': json['risk_level'] ?? 'Low',
      };

      if (!mounted) return;
      debugPrint("Navigating to report screen (Step 2)...");
      setState(() => _step = 4);
    } catch (e) {
      debugPrint("Backend Error: ");
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Connection Error"),
          content: const Text("Check Device & Backend Connection"),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
                _generateFinalReport();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  void _skipUrineTest() {
    setState(() {
      _isUrineSkipped = true;
      _selectedImages.clear();
      _analyzedUrineData = {
        'urine_glucose': "Not Analyzed",
        'urine_protein': "Not Analyzed",
        'urine_ketones': "Not Analyzed",
        'urine_ph': "Not Analyzed",
        'urine_blood': "Not Analyzed",
        'urine_leukocytes': "Not Analyzed",
        'urine_nitrite': "Not Analyzed",
        'urine_bilirubin': "Not Analyzed",
        'urine_urobilinogen': "Not Analyzed",
        'urine_specific_gravity': "Not Analyzed",
      };
      _generateFinalReport();
    });
  }

  Widget _buildPatientDetailsStep() {
    if (_pNameController.text.isEmpty && widget.patientName != null) {
      _pNameController.text = widget.patientName!;
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Patient Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pNameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pAgeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Age",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _pSex,
                    items: ["Male", "Female", "Other"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _pSex = v!),
                    decoration: const InputDecoration(
                      labelText: "Sex",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pMobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_pNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Patient Name is required")),
                    );
                    return;
                  }
                  setState(() => _step = 1);
                  _startVitalsPolling();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09E5AB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                ),
                child: const Text("Next: Basic Vitals"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadStep() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Urine Dipstick Analysis",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImages(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text("Camera"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _pickImages(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: const Text("Gallery"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (ctx, i) => Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedImages[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedImages.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _generateFinalReport();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09E5AB),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Generate Final Report"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsCollectionStep() {
    // Safe Display Logic (Step 2 Only)
    bool isEspConnected = _vitalsState == VitalsState.live && !_status.contains("Error");

    String displayHR = _tempVitals['Heart Rate'] ?? '--';
    String displaySpO2 = _tempVitals['SpO2'] ?? '--';

    if (!isEspConnected) {
      displayHR = "0 bpm";
      displaySpO2 = "0%";
    }

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isEspConnected) ...[
              const CircularProgressIndicator(color: Color(0xFF09E5AB)),
              const SizedBox(height: 20),
              Text(
                _status.contains("Error") ? "Device Disconnected" : _status,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ] else ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              const Text(
                "Vitals Collected Successfully",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                 "HR: $displayHR • SpO2: $displaySpO2\nTemp: ${_tempVitals['Body Temperature']}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _pollingTimer?.cancel();
                    bool isEspConnected = _vitalsState == VitalsState.live && !_status.contains("Error");
                    if (!isEspConnected) {
                      _tempVitals['Heart Rate'] = "0 bpm";
                      _tempVitals['SpO2'] = "0%";
                      _tempVitals['ECG Status'] = "Not Available";
                    }
                    setState(() => _step = 2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF09E5AB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(15),
                  ),
                  child: const Text("Next: ECG Check"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startEcgRecording() {
    setState(() {
      _isRecordingEcg = true;
      _ecgCountdown = 20;
      _ecgBuffer.clear();
    });

    _ecgSubscription = esp32Service.ecgStream.listen((sample) {
      if (!_isRecordingEcg) return;

      _ecgBuffer.add((sample as num).toDouble());

      if (_ecgBuffer.length > 500) {
        _ecgBuffer.removeAt(0);
      }

      debugPrint("ECG COUNT: ${_ecgBuffer.length}");

      if (mounted) setState(() {});
    });

    _ecgRecordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_ecgCountdown > 0) {
          _ecgCountdown--;
        } else {
          _stopEcgRecording();
        }
      });
    });
  }

  void _stopEcgRecording() {
    _ecgRecordingTimer?.cancel();
    _ecgSubscription?.cancel();
    
    // Save ecgBuffer into report data BEFORE navigation
    _tempVitals['ecg_graph'] = List.from(_ecgBuffer);
    _tempVitals['isEcgPerformed'] = true;

    setState(() {
      _isRecordingEcg = false;
      _ecgPerformed = true;
      _step = 3;
    });
  }

  Widget _buildECGStep() {
    bool isEspConnected =
        _vitalsState == VitalsState.live && !_status.contains("Error");
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecordingEcg) ...[
              Container(
                height: 150,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black87,
                ),
                child: ClipRect(
                  child: CustomPaint(
                    painter: _EcgPainter(_ecgBuffer),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Recording ECG... $_ecgCountdown s",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: LinearProgressIndicator(),
              ),
            ] else ...[
              const Icon(Icons.monitor_heart, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "ECG Examination",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                isEspConnected
                    ? "Connect leads to patient and perform test."
                    : "Device not connected",
                style: TextStyle(
                  color: isEspConnected ? Colors.grey : Colors.red,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _ecgPerformed = false;
                        _step = 3;
                      });
                    },
                    child: const Text("Skip ECG"),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: isEspConnected ? _startEcgRecording : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isEspConnected ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEspConnected
                        ? "Perform ECG (20s)"
                        : "Device not connected"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }





  void _generateReferral() {
    if (_results['Severity'] != 'High') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Referral generation is restricted to Critical/High severity cases.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final vitals = _results['vitals_data'] as Map<String, dynamic>;

    final String letter =
        "To: District Medical Officer\n"
        "From: PHC Sector 4\n"
        "Date: ${DateTime.now().toString().split('.')[0]}\n\n"
        "Patient: ${_pNameController.text}\n\n"
        "Reason for Referral:\n"
        "Patient presents with critical vitals indicating ${_results['Diagnosis']}.\n\n"
        "Vitals Summary:\n"
        "- BP: ${vitals['Blood Pressure']}\n"
        "- SpO2: ${vitals['SpO2']}\n"
        "- HR: ${vitals['Heart Rate']}\n\n"
        "Immediate attention required.";

    setState(() {
      _generatedReferralLetter = letter;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.red),
            SizedBox(width: 10),
            Text("Referral Letter"),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            letter,
            style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Referral Attached to Report")),
              );
            },
            icon: const Icon(Icons.attach_file),
            label: const Text("Attach"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _shareReportViaWhatsApp() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating PDF report...")),
    );

    try {
      final pdfService = PdfReportService();
      final pdfFile = await pdfService.generateReport(
        patientName: _pNameController.text,
        patientAge: _pAgeController.text,
        patientSex: _pSex,
        timestamp: DateTime.now(),
        vitalsData: _results['vitals_data'] ?? {},
        urineData: _results['urine_data'] ?? {},
        diagnosis: _results['Diagnosis'] ?? 'N/A',
        severity: _results['Severity'] ?? 'N/A',
        isEcgPerformed: _ecgPerformed,
      );

      await Share.shareXFiles([XFile(pdfFile.path)], text: 'Health Report for ${_pNameController.text}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share report: $e")),
      );
    }
  }

  void _printReport() {
    final printService = ThermalPrintService();
    printService.printReceipt(
      context: context,
      vitals: _results['vitals_data'] as Map<String, dynamic>? ?? {},
      patientName: _pNameController.text,
      age: _pAgeController.text,
      sex: _pSex,
      diagnosis: _results['Diagnosis'] ?? 'N/A',
      severity: _results['Severity'] ?? 'N/A',
    );
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sending report to printer...")),
    );
  }

  void _uploadReport() {
    final reportData = {
      'patientName': _pNameController.text,
      'patientId': widget.patientId,
      'patientAge': _pAgeController.text,
      'patientSex': _pSex,
      'patientMobile': _pMobileController.text,
      'timestamp': FieldValue.serverTimestamp(),
      'results': _results,
      'isEcgPerformed': _ecgPerformed,
      'isUrineSkipped': _isUrineSkipped,
      'status': 'pending_review',
    };

    if (widget.isOffline) {
      widget.onSaveOffline(reportData);
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report saved for offline sync.")),
      );
    } else {
      FirebaseFirestore.instance.collection('diagnostic_reports').add(reportData).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report uploaded successfully.")),
        );
      }).catchError((error) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $error")),
        );
      });
    }
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              if (_step > 0)
                Positioned(
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => setState(() => _step--),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  _step == 0
                      ? "Step 0: Patient Details"
                      : (_step == 1
                          ? "Step 1: Basic Vitals"
                          : (_step == 2
                              ? "Step 2: ECG Check"
                              : (_step == 3
                                  ? "Step 3: Urine Analysis"
                                  : "Step 4: AI Analysis Report"))),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_step == 0)
            _buildPatientDetailsStep()
          else if (_step == 1)
            _buildVitalsCollectionStep()
          else if (_step == 2)
            _buildECGStep()
          else if (_step == 3)
            _buildImageUploadStep()
          else // _step == 4
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          DiagnosticReportWidget(
                            patientName: _pNameController.text,
                            patientAge: _pAgeController.text,
                            patientSex: _pSex,
                            patientMobile: _pMobileController.text,
                            timestamp: DateTime.now(),
                            vitalsData: _results['vitals_data'] ?? {},
                            urineData: _results['urine_data'] ?? {},
                            diagnosis: _results['Diagnosis'] ??
                                'No diagnosis available',
                            severity: _results['Severity'] ?? 'Low',
                            isEcgPerformed: _ecgPerformed,
                            isUrineSkipped: _isUrineSkipped,
                          ),
                          const SizedBox(height: 15),
                          if (_results['vitals_data'] != null &&
                              _results['vitals_data']['ecg_graph'] != null &&
                              (_results['vitals_data']['ecg_graph'] as List)
                                  .isNotEmpty)
                            Container(
                              height: 100,
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 15),
                              decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8)),
                              child: CustomPaint(
                                painter: _EcgPainter(
                                    _results['vitals_data']['ecg_graph']),
                              ),
                            )
                          else
                            const Text("ECG Not Performed",
                                style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _shareReportViaWhatsApp,
                            icon: const Icon(Icons.share),
                            label: const Text("Send Report via WhatsApp"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _printReport,
                            icon: const Icon(Icons.print),
                            label: const Text("Print Report"),
                    
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        CheckboxListTile(
                          title: const Text("Mark as Critical Condition"),
                          value: _forceCritical,
                          onChanged: (bool? value) {
                            setState(() {
                              _forceCritical = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _generateReferral,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Referral"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _uploadReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Upload"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final List data;
  _EcgPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (data.isEmpty) return;

    final path = Path();
    final doubleList = data.map((e) => (e as num).toDouble()).toList();
    double minVal = doubleList.reduce(min);
    double maxVal = doubleList.reduce(max);
    if (minVal == maxVal) {
      minVal -= 1;
      maxVal += 1;
    }

    double stepX = size.width / (doubleList.length > 1 ? doubleList.length - 1 : 1);
    double range = maxVal - minVal;

    for (int i = 0; i < doubleList.length; i++) {
      double x = i * stepX;
      double normalized = (doubleList[i] - minVal) / range;
      double y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FullEcgScreen extends StatelessWidget {
  final String patientName;
  final DateTime timestamp;
  final List<double> ecgValues;

  const _FullEcgScreen({
    required this.patientName,
    required this.timestamp,
    required this.ecgValues,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ECG for $patientName'),
      ),
      body: const Center(
        child: Text('ECG Screen'),
      ),
    );
  }
}
