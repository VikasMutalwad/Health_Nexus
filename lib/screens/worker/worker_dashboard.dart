import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_session.dart';
import '../../models/health_record.dart'; // Import model
import 'dart:math';

class HealthWorkerDashboard extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const HealthWorkerDashboard({
    super.key, 
    required this.session, 
    required this.onLogout
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
        title: const Text("PHC Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Switch(
            value: _isOffline,
            onChanged: (val) {
              setState(() => _isOffline = val);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_isOffline ? "Offline Mode Enabled" : "Online Mode Restored"),
                backgroundColor: _isOffline ? Colors.orange : Colors.green,
              ));
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
            icon: const Icon(Icons.logout)
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
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: "Education"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isOffline ? null : () async {
          bool synced = false;
          if (_pendingRecords.isNotEmpty) {
            setState(() => _pendingRecords.clear());
            synced = true;
          }
          
          if (_pendingReports.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (var report in _pendingReports) {
              final docRef = FirebaseFirestore.instance.collection('diagnostic_reports').doc();
              report['uploadedAt'] = FieldValue.serverTimestamp(); // Add upload time
              batch.set(docRef, report);
            }
            await batch.commit();
            setState(() => _pendingReports.clear());
            synced = true;
          }

          if (!mounted) return;

          if (synced) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Synced all offline data to Cloud!")));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All records are up to date.")));
          }
        },
        backgroundColor: _isOffline ? Colors.grey : const Color(0xFF09E5AB),
        label: Text(_isOffline ? "Offline (${_pendingRecords.length + _pendingReports.length})" : "Sync Data"),
        icon: Icon(_isOffline ? Icons.cloud_off : Icons.cloud_upload),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0: return _buildPatientList();
      case 1: return _buildEducationHub();
      case 2: return _buildHistoryView();
      default: return _buildPatientList();
    }
  }

  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Diagnostic History", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text("Past reports and uploads", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('diagnostic_reports').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No history found"));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final results = data['results'] as Map<String, dynamic>? ?? {};
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.assignment, color: Colors.blue),
                      ),
                      title: Text(data['patientName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Date: ${timestamp.toString().split('.')[0]}"),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: (data['status'] == 'reviewed') ? Colors.green.withAlpha(26) : Colors.orange.withAlpha(26),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(
                          data['status']?.toUpperCase() ?? 'PENDING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 10,
                            color: (data['status'] == 'reviewed') ? Colors.green : Colors.orange
                          )
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Vitals & Results:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 5),
                              ...results.entries.map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.key),
                                    Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
                              if (data['prescription'] != null) ...[
                                const Divider(),
                                const Text("Doctor's Note:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                const SizedBox(height: 5),
                                Text(data['prescription']),
                              ]
                            ],
                          ),
                        )
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
        const Text("Community Triage", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text("${_pendingRecords.length} Pending Sync", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search patients...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
        const SizedBox(height: 20),

        _buildHardwareStatus(),
        // New Diagnostic Kit Card
        GestureDetector(
          onTap: _openDiagnosticKit,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF334155)]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.blue.withAlpha(77), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.medical_services_outlined, color: Color(0xFF09E5AB), size: 30),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Run Diagnostic Test (HD009)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Blood • Urine • Vitals AI Analysis", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
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
        const SizedBox(height: 25),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('diagnostic_reports').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs;
              
              var filteredDocs = docs;
              if (_searchQuery.isNotEmpty) {
                filteredDocs = filteredDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['patientName'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }

              if (_filterStatus == 'Critical') {
                filteredDocs = filteredDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final results = data['results'] as Map<String, dynamic>? ?? {};
                  return results['Severity'] == 'High';
                }).toList();
              } else if (_filterStatus == 'Pending') {
                filteredDocs = filteredDocs.where((d) => d['status'] == 'pending_review').toList();
              } else if (_filterStatus == 'Ready') {
                filteredDocs = filteredDocs.where((d) => d['status'] == 'reviewed').toList();
              }

              final pending = filteredDocs.where((d) => d['status'] == 'pending_review').toList();
              final ready = filteredDocs.where((d) => d['status'] == 'reviewed').toList();
              final completed = filteredDocs.where((d) {
                if (d['status'] != 'completed') return false;
                final ts = (d['timestamp'] as Timestamp).toDate();
                final now = DateTime.now();
                return ts.year == now.year && ts.month == now.month && ts.day == now.day;
              }).toList();

              return ListView(
                children: [
                  if (ready.isNotEmpty) ...[
                    const Text("Ready to Dispense", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    ...ready.map((doc) => _buildReportCard(doc, true)),
                    const SizedBox(height: 20),
                  ],
                  if (pending.isNotEmpty) ...[
                    const Text("Pending Doctor Review", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    ...pending.map((doc) => _buildReportCard(doc, false)),
                    const SizedBox(height: 20),
                  ],
                  if (completed.isNotEmpty) ...[
                    const Text("Completed Today", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    ...completed.map((doc) => _buildReportCard(doc, false, isCompleted: true)),
                    const SizedBox(height: 20),
                  ],
                ],
              );
            },
          ),
        )
      ],
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
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
    );
  }

  Widget _buildReportCard(QueryDocumentSnapshot doc, bool isActionable, {bool isCompleted = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final results = data['results'] as Map<String, dynamic>? ?? {};
    final severity = results['Severity'] ?? 'Low';
    Color color = severity == 'High' ? Colors.red : (severity == 'Moderate' ? Colors.orange : Colors.green);
    if (isCompleted) color = Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withAlpha(26), child: Icon(isCompleted ? Icons.check : Icons.medical_services, color: color)),
        title: Text(data['patientName'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, decoration: isCompleted ? TextDecoration.lineThrough : null)),
        subtitle: Text("Diagnosis: ${results['Diagnosis'] ?? '--'}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
              onPressed: () => _showChatDialog(doc.id, data['patientName'] ?? 'Unknown'),
            ),
            const SizedBox(width: 8),
            if (isActionable)
              ElevatedButton(
                onPressed: () => _showPrescriptionDialog(data['patientName'], data['prescription'] ?? data['referralLetter'] ?? "No details", doc.id),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("Dispense"),
              )
            else
              (isCompleted ? const Icon(Icons.check_circle, color: Colors.green) : const Text("Waiting...", style: TextStyle(color: Colors.orange))),
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
        title: Text("Chat: $patientName"),
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
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final msgs = snapshot.data!.docs;
                    if (msgs.isEmpty) return const Center(child: Text("No messages yet."));
                    return ListView.builder(
                      reverse: true,
                      itemCount: msgs.length,
                      itemBuilder: (ctx, i) {
                        final m = msgs[i].data() as Map<String, dynamic>;
                        final isMe = m['role'] == 'worker';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['message'], style: const TextStyle(fontSize: 14)),
                                Text(m['senderName'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.black54)),
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
                  Expanded(child: TextField(controller: msgController, decoration: const InputDecoration(hintText: "Type a message..."))),
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
                  )
                ],
              )
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  void _showPrescriptionDialog(String patientName, String prescription, [String? docId]) {
    bool isReferral = prescription.contains("To: District Medical Officer");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isReferral ? Icons.assignment_late : Icons.medical_services, color: isReferral ? Colors.red : Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text("${isReferral ? 'Referral' : 'Rx'}: $patientName", style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: isReferral ? Colors.red.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
          child: Text(prescription, style: const TextStyle(fontSize: 16, height: 1.5)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton(
            onPressed: () {
              if (docId != null && !isReferral) {
                FirebaseFirestore.instance.collection('diagnostic_reports').doc(docId).update({'status': 'completed'});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medicines Dispensed. Patient Completed.")));
              }
              Navigator.pop(ctx);
            },
            child: Text(isReferral ? "Share / Print" : "Dispense Meds")
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(Icons.power_settings_new, "ON", "Kit Status", Colors.green),
          _buildStatusItem(Icons.science, "42", "Strips Left", Colors.blue, onTap: _showRestockDialog),
          _buildStatusItem(Icons.build, "OK", "Calibration", Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String value, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
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
              items: ["Glucose Strips", "Urine Strips", "Lancets", "Batteries", "Sanitizer"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('inventory_requests').add({
                'item': selectedItem,
                'quantity': int.tryParse(qtyController.text) ?? 0,
                'requestedAt': FieldValue.serverTimestamp(),
                'status': 'pending',
                'phcId': 'sector-4', // Mock ID
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent to Central Supply")));
            },
            child: const Text("Submit Request"),
          )
        ],
      ),
    );
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
            Text("Scanning Patient QR...", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context); // Close scanner

    // Simulate finding a patient
    String scannedName = "Rahul Sharma";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Patient Identified: $scannedName")));
    
    // Open kit for this patient
    _openDiagnosticKit(patientName: scannedName);
  }

  void _openDiagnosticKit({String? patientName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DiagnosticKitOverlay(
        isOffline: _isOffline,
        patientName: patientName,
        onSaveOffline: (report) {
          setState(() => _pendingReports.add(report));
        },
      ),
    );
  }

  Widget _buildEducationHub() {
    final List<Map<String, String>> videos = [
      {"title": "Prenatal Care Basics", "duration": "5:30", "category": "Maternal"},
      {"title": "Managing Hypertension", "duration": "4:15", "category": "Chronic"},
      {"title": "Hygiene & Sanitation", "duration": "3:45", "category": "General"},
      {"title": "Vaccination Schedule", "duration": "6:10", "category": "Pediatric"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Patient Education Hub", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text("Educational materials for community awareness", style: TextStyle(color: Colors.grey)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: const Center(child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(v['category']!, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                              Text(v['duration']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    )
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

class _DiagnosticKitOverlay extends StatefulWidget {
  final bool isOffline;
  final String? patientName;
  final Function(Map<String, dynamic>) onSaveOffline;
  const _DiagnosticKitOverlay({required this.isOffline, required this.onSaveOffline, this.patientName});

  @override
  State<_DiagnosticKitOverlay> createState() => _DiagnosticKitOverlayState();
}

class _DiagnosticKitOverlayState extends State<_DiagnosticKitOverlay> {
  int _step = 0;
  String _status = "Connecting to HD009 Kit...";
  Map<String, dynamic> _results = {};
  String? _generatedReferralLetter;
  bool _forceCritical = false;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  void _runSimulation() async {
    await Future.delayed(const Duration(seconds: 2));
    if(mounted) setState(() => _status = "Analyzing Blood Sample...");
    await Future.delayed(const Duration(seconds: 2));
    if(mounted) setState(() => _status = "Processing Urine Dipstick...");
    await Future.delayed(const Duration(seconds: 2));
    if(mounted) setState(() => _status = "AI Interpreting Results...");
    await Future.delayed(const Duration(seconds: 2));
    
    if(mounted) {
      // Dynamic AI Simulation: Generate random sensor data
      final random = Random();
      double hb = 10.5 + random.nextDouble() * 5.5; // Range: 10.5 - 16.0
      int glucose = 70 + random.nextInt(180); // Range: 70 - 250
      int sys = 100 + random.nextInt(60); // Range: 100 - 160
      int dia = 60 + random.nextInt(40); // Range: 60 - 100
      int spo2 = 92 + random.nextInt(8); // Range: 92 - 100
      int hr = 60 + random.nextInt(40); // Range: 60 - 100
      bool proteinPos = random.nextDouble() > 0.7; // 30% chance of positive

      // Edge AI Logic: Interpret results instantly
      List<String> conditions = [];
      if (hb < 12.0) conditions.add("Anemia");
      if (glucose > 140) conditions.add("Diabetes Risk");
      if (sys > 140 || dia > 90) conditions.add("Hypertension");
      if (spo2 < 95) conditions.add("Hypoxia");
      if (proteinPos) conditions.add("Proteinuria");

      String diagnosis = conditions.isEmpty ? "Healthy / Normal" : conditions.join(" & ");
      String severity = (conditions.length >= 2 || spo2 < 90 || sys > 160) ? "High" : (conditions.isNotEmpty ? "Moderate" : "Low");

      setState(() {
        _step = 1;
        _results = {
          'Hemoglobin': '${hb.toStringAsFixed(1)} g/dL',
          'Glucose': '$glucose mg/dL',
          'Urine Protein': proteinPos ? '++' : 'Negative',
          'Blood Pressure': '$sys/$dia mmHg',
          'Heart Rate': '$hr bpm',
          'SpO2': '$spo2%',
          'Diagnosis': diagnosis,
          'Severity': severity,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.green;
    if (_results['Severity'] == 'High') statusColor = Colors.red;
    if (_results['Severity'] == 'Moderate') statusColor = Colors.orange;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(_step == 0 ? "Running Diagnostics" : "AI Analysis Report", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          if (_step == 0) ...[
            const CircularProgressIndicator(color: Color(0xFF09E5AB)),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ] else ...[
            Expanded(
              child: ListView(
                children: [
                  _buildResultRow("Hemoglobin", _results['Hemoglobin'], Colors.red),
                  _buildResultRow("Random Glucose", _results['Glucose'], Colors.orange),
                  _buildResultRow("Urine Protein", _results['Urine Protein'], Colors.orange),
                  _buildResultRow("Blood Pressure", _results['Blood Pressure'], Colors.black87),
                  _buildResultRow("SpO2", _results['SpO2'], Colors.black87),
                  const Divider(),
                  const Text("AI Interpretation:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(15),                    decoration: BoxDecoration(color: statusColor.withAlpha(26), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withAlpha(77))),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, color: statusColor),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_results['Diagnosis'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text("Mark as Critical Condition", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              value: _forceCritical,
              onChanged: (val) => setState(() => _forceCritical = val ?? false),
              activeColor: Colors.red,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generateReferral,
                    icon: const Icon(Icons.assignment_late, color: Colors.red),
                    label: const Text("Referral", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_forceCritical) {
                        _results['Severity'] = 'High';
                      }

                      // Upload to Cloud
                      final reportData = {
                        'patientName': widget.patientName ?? 'Unknown (Walk-in)',
                        'results': _results,
                        'timestamp': DateTime.now(), // Use local time initially
                        'referralLetter': _generatedReferralLetter,
                        'status': 'pending_review'
                      };

                      if (widget.isOffline) {
                        widget.onSaveOffline(reportData);
                        if(mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Saved Locally (Offline Mode)")));
                        }
                      } else {
                        await FirebaseFirestore.instance.collection('diagnostic_reports').add(reportData);
                        if(mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Sent to Doctor for Confirmation")));
                        }
                      }
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Upload"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09E5AB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _generateReferral() {
    if (_results['Severity'] != 'High') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral generation is restricted to Critical/High severity cases."), backgroundColor: Colors.orange));
      return;
    }

    final String letter = 
            "To: District Medical Officer\n"
            "From: PHC Sector 4\n"
            "Date: ${DateTime.now().toString().split('.')[0]}\n\n"
            "Patient: ${widget.patientName ?? 'Unknown'}\n\n"
            "Reason for Referral:\n"
            "Patient presents with critical vitals indicating ${_results['Diagnosis']}.\n\n"
            "Vitals Summary:\n"
            "- BP: ${_results['Blood Pressure']}\n"
            "- SpO2: ${_results['SpO2']}\n"
            "- Glucose: ${_results['Glucose']}\n\n"
            "Immediate attention required.";

    setState(() {
      _generatedReferralLetter = letter;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.local_hospital, color: Colors.red), SizedBox(width: 10), Text("Referral Letter")]),
        content: SingleChildScrollView(
          child: Text(letter, style: const TextStyle(fontFamily: 'Monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral Attached to Report")));
            },
            icon: const Icon(Icons.attach_file),
            label: const Text("Attach"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }
}