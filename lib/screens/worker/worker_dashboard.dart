import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../models/health_record.dart'; // Import model

class HealthWorkerDashboard extends StatelessWidget {
  final UserSession session;
  final VoidCallback onLogout;

  HealthWorkerDashboard({
    super.key, 
    required this.session, 
    required this.onLogout
  });

  // Mock Data (Baad mein Firebase se replace hoga)
  final List<HealthRecord> mockPatients = [
    HealthRecord(patientName: "Rahul Sharma", hr: "105 bpm", spo2: "94%", status: "Critical"),
    HealthRecord(patientName: "Priya V.", hr: "72 bpm", spo2: "98%", status: "Normal"),
    HealthRecord(patientName: "Amit Kumar", hr: "88 bpm", spo2: "96%", status: "Warning"),
    HealthRecord(patientName: "Sunita Devi", hr: "68 bpm", spo2: "99%", status: "Normal"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Nexus: PHC Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: onLogout, 
            icon: const Icon(Icons.logout)
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Community Triage", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("${mockPatients.length} Active Patients in your area", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 25),
                Expanded(
                  child: ListView.builder(
                    itemCount: mockPatients.length,
                    itemBuilder: (context, index) {
                      final p = mockPatients[index];
                      // Logic for Color Coding
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
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(p.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          onTap: () {
                            // Navigation logic to patient detail will come here
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening Patient Details...")));
                          },
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            // Sync Logic
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing Data with Cloud...")));
        },
        label: const Text("Sync All Nodes"),
        icon: const Icon(Icons.sync),
      ),
    );
  }
}