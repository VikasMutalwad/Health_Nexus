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

  // Mock Data (Baad mein Firebase se replace hoga)
  final List<HealthRecord> mockPatients = [
    HealthRecord(patientName: "Rahul Sharma", hr: "105 bpm", spo2: "94%", status: "Critical"),
    HealthRecord(patientName: "Priya V.", hr: "72 bpm", spo2: "98%", status: "Normal"),
    HealthRecord(patientName: "Amit Kumar", hr: "88 bpm", spo2: "96%", status: "Warning"),
    HealthRecord(patientName: "Sunita Devi", hr: "68 bpm", spo2: "99%", status: "Normal"),
  ];

  // Mock Prescriptions from Doctor (Simulating Doctor -> Worker Flow)
  final Map<String, String> _doctorPrescriptions = {
    "Rahul Sharma": "Inj. Lasix 40mg IV Stat\nTab. Telmisartan 40mg OD\nMonitor BP every 2 hours",
    "Amit Kumar": "Tab. Dolo 650mg TDS for 3 days\nSyp. Ambroxol 10ml BD\nSteam Inhalation",
  };

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
            child: _selectedIndex == 0 ? _buildPatientList() : _buildGeoMap(),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Patients"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Disease Map"),
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

  Widget _buildPatientList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Community Triage", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text("${mockPatients.length} Active Patients | ${_pendingRecords.length} Pending Sync", style: const TextStyle(color: Colors.grey)),
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
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
        const SizedBox(height: 25),
        Expanded(
          child: ListView.builder(
            itemCount: mockPatients.length,
            itemBuilder: (context, index) {
              final p = mockPatients[index];
              Color statusColor = p.status == 'Critical' 
                  ? Colors.red 
                  : (p.status == 'Warning' ? Colors.orange : Colors.green);
              
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: statusColor),
                  ),
                  title: Text(p.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("HR: ${p.hr} | SpO2: ${p.spo2}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_doctorPrescriptions.containsKey(p.patientName))
                        IconButton(
                          icon: const Icon(Icons.description_outlined, color: Colors.blue),
                          onPressed: () => _showPrescriptionDialog(p.patientName, _doctorPrescriptions[p.patientName]!),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(p.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (_isOffline) {
                      // Simulate adding a record offline
                      setState(() {
                        _pendingRecords.add(p);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vitals recorded locally. Sync when online.")));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening Patient Details...")));
                    }
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }

  void _showPrescriptionDialog(String patientName, String prescription) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.medical_services, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text("Rx: $patientName", style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
          child: Text(prescription, style: const TextStyle(fontSize: 16, height: 1.5)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Dispense Meds")),
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
          _buildStatusItem(Icons.science, "42", "Strips Left", Colors.blue),
          _buildStatusItem(Icons.build, "OK", "Calibration", Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
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

  Widget _buildGeoMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Geospatial Disease Mapping", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text("Visualizing patient clusters in your sector", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _MapPainter(mockPatients),
                child: const Center(child: Text("Sector 4 Map View", style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold, fontSize: 24))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<HealthRecord> patients;
  _MapPainter(this.patients);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42); // Fixed seed for consistency

    // Draw Grid
    final gridPaint = Paint()..color = Colors.blue.withOpacity(0.1)..strokeWidth = 1;
    for(double i=0; i<size.width; i+=40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for(double i=0; i<size.height; i+=40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw Patients
    for (var p in patients) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      Color color = p.status == 'Critical' ? Colors.red : (p.status == 'Warning' ? Colors.orange : Colors.green);
      paint.color = color.withOpacity(0.6);
      
      // Draw "Heatmap" glow
      canvas.drawCircle(Offset(x, y), 15, paint);
      
      // Draw Core
      paint.color = color;
      canvas.drawCircle(Offset(x, y), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    bool isCritical = _results['Severity'] == 'High';

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
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withOpacity(0.3))),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, color: statusColor),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_results['Diagnosis'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16))),
                      ],
                    ),
                  ),
                  if (isCritical) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _generateReferral,
                        icon: const Icon(Icons.assignment_late, color: Colors.red),
                        label: const Text("Generate Urgent Referral", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Upload to Cloud
                  final reportData = {
                    'patientName': widget.patientName ?? 'Unknown (Walk-in)',
                    'results': _results,
                    'timestamp': DateTime.now(), // Use local time initially
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
                label: const Text("Upload to Specialist"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09E5AB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.local_hospital, color: Colors.red), SizedBox(width: 10), Text("Referral Letter")]),
        content: SingleChildScrollView(
          child: Text(
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
            "Immediate attention required.",
            style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral Letter Shared via WhatsApp")));
            },
            icon: const Icon(Icons.share),
            label: const Text("Share"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }
}