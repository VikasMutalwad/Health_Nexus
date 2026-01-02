import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_session.dart';
import '../../models/health_record.dart';
import 'dart:math';

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
  int _selectedIndex = 0;
  late Stream<QuerySnapshot> _referralsStream;

  // Mock Data for Doctor View
  final List<HealthRecord> _allPatients = [
    HealthRecord(patientName: "Rahul Sharma", hr: "105 bpm", spo2: "94%", status: "Critical"),
    HealthRecord(patientName: "Amit Kumar", hr: "88 bpm", spo2: "96%", status: "Warning"),
    HealthRecord(patientName: "Priya V.", hr: "72 bpm", spo2: "98%", status: "Normal"),
    HealthRecord(patientName: "Sunita Devi", hr: "68 bpm", spo2: "99%", status: "Normal"),
    HealthRecord(patientName: "John Doe", hr: "70 bpm", spo2: "98%", status: "Normal"),
  ];

  @override
  void initState() {
    super.initState();
    _referralsStream = FirebaseFirestore.instance
        .collection('diagnostic_reports')
        .where('status', isEqualTo: 'pending_review')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Doctor Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.people), label: Text('Patients')),
                NavigationRailDestination(icon: Icon(Icons.map), label: Text('Map')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month), label: Text('Schedule')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (int index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
                BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Schedule'),
              ],
            )
          : null,
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardView();
      case 1: return _buildAllPatientsView();
      case 2: return _buildMapView();
      case 3: return _buildScheduleView();
      default: return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return StreamBuilder<QuerySnapshot>(
      stream: _referralsStream,
      builder: (context, snapshot) {
        int pendingCount = 0;
        int criticalCount = 0;
        List<QueryDocumentSnapshot> docs = [];

        if (snapshot.hasError) {
          return Center(child: Text("Error loading data: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        if (snapshot.hasData) {
          docs = snapshot.data!.docs;
          pendingCount = docs.length;
          criticalCount = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['results']?['Severity'] == 'High';
          }).length;
        }

        Widget statsSection = Column(
          children: [
            _buildStatCard("Pending Reviews", "$pendingCount", Colors.orange),
            const SizedBox(height: 15),
            _buildStatCard("Completed Today", "12", Colors.green),
            const SizedBox(height: 15),
            _buildStatCard("Critical Alerts", "$criticalCount", Colors.red),
          ],
        );

        Widget mainContentSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Urgent Referrals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : (docs.isEmpty
                      ? const Center(child: Text("No pending referrals"))
                      : ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final results = data['results'] as Map<String, dynamic>? ?? {};
                            
                            final String name = data['patientName'] ?? 'Unknown';
                            final String hr = results['Heart Rate'] ?? '--';
                            final String spo2 = results['SpO2'] ?? '--';
                            final String severity = results['Severity'] ?? 'Unknown';
                            
                            Color statusColor = severity == 'High' ? Colors.red : (severity == 'Moderate' ? Colors.orange : Colors.green);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: statusColor.withOpacity(0.1),
                                      child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text("Vitals: HR $hr | SpO2 $spo2", style: const TextStyle(color: Colors.grey)),
                                          Text("Status: $severity", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _openPatientReview(doc.id, data),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                      child: const Text("Review"),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: isMobile
              ? Column(
                  children: [
                    statsSection,
                    const SizedBox(height: 20),
                    Expanded(child: mainContentSection),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: statsSection),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: mainContentSection),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAllPatientsView() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allPatients.length,
      itemBuilder: (context, index) {
        final p = _allPatients[index];
        return ListTile(
          leading: CircleAvatar(child: Text(p.patientName[0])),
          title: Text(p.patientName),
          subtitle: Text("Status: ${p.status}"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        );
      },
    );
  }

  Widget _buildMapView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Disease Outbreak Map", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _MapPainter(_allPatients),
                  child: Container(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text("Upcoming Appointments", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        ListTile(
          leading: Icon(Icons.access_time, color: Colors.blue),
          title: Text("Follow-up: Rahul Sharma"),
          subtitle: Text("Today, 2:00 PM - Video Call"),
        ),
        ListTile(
          leading: Icon(Icons.access_time, color: Colors.blue),
          title: Text("Consultation: Priya V."),
          subtitle: Text("Tomorrow, 10:00 AM - In Person"),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  void _openPatientReview(String docId, Map<String, dynamic> data) {
    final TextEditingController prescriptionCtrl = TextEditingController();
    final results = data['results'] as Map<String, dynamic>? ?? {};
    final String name = data['patientName'] ?? 'Unknown';
    final String diagnosis = results['Diagnosis'] ?? 'No diagnosis';
    final String hr = results['Heart Rate'] ?? '--';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Review: $name"),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(child: Text("AI Insight: $diagnosis", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.red),
                    ...results.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13)),
                          Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text("Prescription / Advice:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: prescriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter medication, dosage, and instructions...",
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Calling PHC Worker...")));
            },
            icon: const Icon(Icons.video_call),
            label: const Text("Video Call"),
          ),
          ElevatedButton(
            onPressed: () {
              // Update Firestore
              FirebaseFirestore.instance.collection('diagnostic_reports').doc(docId).update({
                'status': 'reviewed',
                'prescription': prescriptionCtrl.text,
                'reviewedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prescription Sent to PHC!")));
            },
            child: const Text("Send Prescription"),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<HealthRecord> patients;
  _MapPainter(this.patients);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    final gridPaint = Paint()..color = Colors.blue.withOpacity(0.1)..strokeWidth = 1;
    for(double i=0; i<size.width; i+=40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for(double i=0; i<size.height; i+=40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    for (var p in patients) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      Color color = p.status == 'Critical' ? Colors.red : (p.status == 'Warning' ? Colors.orange : Colors.green);
      paint.color = color.withOpacity(0.6);
      canvas.drawCircle(Offset(x, y), 15, paint);
      paint.color = color;
      canvas.drawCircle(Offset(x, y), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}