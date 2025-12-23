import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health_nexus/screens/patient/patient_detail_screen.dart';
import '../../models/user_session.dart';
import '../../widgets/stat_card.dart'; // Reusing your widget


class DoctorDashboard extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const DoctorDashboard({super.key, required this.session, required this.onLogout});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Doctor Dashboard", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout, color: Colors.red)),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        selectedItemColor: const Color(0xFF09E5AB),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active), label: "Requests"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Appts"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        backgroundColor: const Color(0xFF09E5AB),
        onPressed: _showAddPatientDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildDashboard();
      case 1: return _buildRequests();
      case 2: return _buildAppointments();
      case 3: return _buildChatList();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'patient').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading patients"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final patients = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row using Custom StatCard
                  Row(
                    children: [
                      Expanded(child: StatCard(
                        title: "Total Patients", 
                        value: "${patients.length}", 
                        icon: Icons.people, 
                        bgColor: Colors.blue.shade50,
                        iconColor: Colors.blue,
                      )),
                      const SizedBox(width: 15),
                      Expanded(child: StatCard(
                        title: "Appointments", 
                        value: "12", 
                        icon: Icons.calendar_today, 
                        bgColor: Colors.orange.shade50,
                        iconColor: Colors.orange,
                      )),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("Patient List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final doc = patients[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final vitals = data['vitals'] as Map<String, dynamic>? ?? {};
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.blue.shade50,
                                    child: Text(
                                      (data['name'] ?? data['username'] ?? "U").toString().substring(0, 1).toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['name'] ?? data['username'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text("ID: ${doc.id.substring(0, 5)}... | ${data['gender'] ?? 'N/A'}, ${data['age'] ?? '0'} yrs", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deletePatient(doc.id),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildVitalPreview("HR", "${vitals['Heart Rate']?.toStringAsFixed(0) ?? '--'} bpm"),
                                  _buildVitalPreview("BP", "${vitals['Blood Pressure']?.toStringAsFixed(0) ?? '--'}"),
                                  _buildVitalPreview("SpO2", "${vitals['SpO2']?.toStringAsFixed(0) ?? '--'}%"),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorPatientDetailScreen(patientId: doc.id, data: data))),
                                  child: const Text("View Full Records & Chat"),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No Pending Requests"));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final vitals = data['vitals'] as Map<String, dynamic>? ?? {};

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['patientName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text("Requesting Appointment", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                          onPressed: () => doc.reference.update({'status': 'confirmed'}),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                          onPressed: () => doc.reference.delete(),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text("Vitals at Request:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vitals.entries.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)),
                        child: Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 12)),
                      )).toList(),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppointments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').where('status', isEqualTo: 'confirmed').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No Upcoming Appointments"));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE2F6ED), child: Icon(Icons.calendar_today, color: Color(0xFF28A745))),
                title: Text(data['patientName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Confirmed Appointment"),
                trailing: IconButton(
                  icon: const Icon(Icons.video_call, color: Colors.blue),
                  onPressed: (){},
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatList() {
    return const Center(child: Text("Select a patient from Dashboard to Chat"));
  }

  Widget _buildVitalPreview(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showAddPatientDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Patient"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').add({
                  'username': emailCtrl.text,
                  'name': nameCtrl.text,
                  'role': 'patient',
                  'age': 30,
                  'gender': 'Male',
                  'vitals': {},
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  void _deletePatient(String docId) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
  }
}