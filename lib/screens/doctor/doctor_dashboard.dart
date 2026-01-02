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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _referralsStream = FirebaseFirestore.instance
        .collection('diagnostic_reports')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile) ...[
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.people), label: Text('Patients')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month), label: Text('Schedule')),
                NavigationRailDestination(icon: Icon(Icons.history), label: Text('History')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(
            child: _buildContent(context),
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
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Schedule'),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
              ],
            )
          : null,
    );
  }

  // ==== FIX 1: pass BuildContext so `context` is defined ====
  Widget _buildContent(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView(context);
      case 1:
        return _buildAllPatientsView(context);
      case 2:
        return _buildScheduleView(context);
      case 3:
        return _buildHistoryView();
      default:
        return _buildDashboardView(context);
    }
  }

  // ==== Also accept BuildContext where MediaQuery / ScaffoldMessenger are used ====
  Widget _buildDashboardView(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return StreamBuilder<QuerySnapshot>(
      stream: _referralsStream,
      builder: (context, snapshot) {
        int pendingCount = 0;
        int criticalCount = 0;
        int completedTodayCount = 0;
        List<QueryDocumentSnapshot> docs = [];
        List<QueryDocumentSnapshot> criticalDocs = [];
        List<QueryDocumentSnapshot> normalPendingDocs = [];
        List<QueryDocumentSnapshot> completedDocs = [];

        if (snapshot.hasError) {
          return Center(
              child: Text("Error loading data: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)));
        }

        if (snapshot.hasData) {
          docs = snapshot.data!.docs;
          final allPending = docs.where((d) => d['status'] == 'pending_review').toList();

          criticalDocs = allPending.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final results = data['results'] as Map<String, dynamic>?;
            return results?['Severity'] == 'High';
          }).toList();

          normalPendingDocs =
              allPending.where((doc) => !criticalDocs.contains(doc)).toList();

          completedDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (data['status'] != 'reviewed' && data['status'] != 'completed') return false;
            final Timestamp? ts = data['reviewedAt'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();
            final now = DateTime.now();
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList();

          pendingCount = normalPendingDocs.length;
          criticalCount = criticalDocs.length;
          completedTodayCount = completedDocs.length;
        }

        Widget statsSection = SingleChildScrollView(
          child: Column(
            children: [
              _buildStatCard("Pending Reviews", "$pendingCount", Colors.orange),
              const SizedBox(height: 15),
              _buildStatCard("Completed Today", "$completedTodayCount", Colors.green),
              const SizedBox(height: 15),
              _buildStatCard("Critical Alerts", "$criticalCount", Colors.red),
            ],
          ),
        );

        Widget mainContentSection = ListView(
          padding: EdgeInsets.zero,
          children: [
            if (criticalDocs.isNotEmpty) ...[
              const Text("Critical Alerts",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  children:
                      criticalDocs.map((doc) => _buildPatientCard(doc, context)).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text("Pending Reviews",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            snapshot.connectionState == ConnectionState.waiting
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()))
                : (normalPendingDocs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text("No pending referrals")))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: normalPendingDocs.length,
                        itemBuilder: (context, index) {
                          return _buildPatientCard(normalPendingDocs[index], context);
                        },
                      )),
            if (completedDocs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("Completed Today",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: completedDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        completedDocs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(data['patientName'] ?? 'Unknown'),
                      subtitle: Text(data['status'] == 'completed'
                          ? 'Dispensed'
                          : 'Prescription Sent'),
                    );
                  },
                ),
              )
            ]
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

  // ==== pass context into card so it can call _openPatientReview safely ====
  Widget _buildPatientCard(QueryDocumentSnapshot doc, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final results = data['results'] as Map<String, dynamic>? ?? {};

    final String name = data['patientName'] ?? 'Unknown';
    final String hr = results['Heart Rate'] ?? '--';
    final String spo2 = results['SpO2'] ?? '--';
    final String severity = results['Severity'] ?? 'Unknown';

    Color statusColor = severity == 'High'
        ? Colors.red
        : (severity == 'Moderate' ? Colors.orange : Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withAlpha(26),
              child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text("Vitals: HR $hr | SpO2 $spo2",
                      style: const TextStyle(color: Colors.grey)),
                  Text("Status: $severity",
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
              onPressed: () => _showChatDialog(doc.id, name),
              tooltip: "Chat with Worker",
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _openPatientReview(doc.id, data, context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white),
              child: const Text("Review"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllPatientsView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search patients by name...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _clearCollection(context, 'diagnostic_reports'),
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: "Clear All Patients",
              ),
            ],
          ),
        ),
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
              final Map<String, Map<String, dynamic>> uniquePatients = {};

              // Deduplicate patients (show latest record info)
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['patientName'] ?? 'Unknown';
                if (!uniquePatients.containsKey(name)) {
                  uniquePatients[name] = data;
                }
              }

              var patients = uniquePatients.values.toList();

              if (_searchQuery.isNotEmpty) {
                patients = patients
                    .where((p) => (p['patientName'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery))
                    .toList();
              }

              if (patients.isEmpty) {
                return const Center(child: Text("No patients found"));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final data = patients[index];
                  final results = data['results'] as Map<String, dynamic>? ?? {};
                  final severity = results['Severity'] ?? 'Normal';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Text(
                            (data['patientName'] ?? '?')[0],
                            style: const TextStyle(
                                color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(data['patientName'] ?? 'Unknown'),
                      subtitle: Text("Last Status: $severity"),
                      trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Opening history for ${data['patientName']}"),
                          ),
                        );
                      },
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

  Widget _buildScheduleView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Appointments", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => _clearCollection(context, 'appointments'),
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: "Clear Schedule",
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('appointments').orderBy('requestDate', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No appointments found"));

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final patientName = data['patientName'] ?? 'Unknown';
                  final timestamp = (data['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final doctorMessage = data['doctorMessage'];

                  Color statusColor = status == 'confirmed' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withAlpha(30),
                        child: Icon(Icons.calendar_today, color: statusColor),
                      ),
                      title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Status: ${status.toUpperCase()}"),
                          Text("Date: ${timestamp.toString().split('.')[0]}"),
                          if (doctorMessage != null && doctorMessage.toString().isNotEmpty)
                            Text("Msg: $doctorMessage", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ],
                      ),
                      children: [
                        if (status == 'pending')
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _showDecisionDialog(context, doc.id, 'rejected'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                    child: const Text("Reject"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _showDecisionDialog(context, doc.id, 'confirmed'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: const Text("Accept"),
                                  ),
                                ),
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

  void _showDecisionDialog(BuildContext context, String docId, String status) {
    final TextEditingController msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${status == 'confirmed' ? 'Accept' : 'Reject'} Appointment?"),
        content: TextField(
          controller: msgController,
          decoration: const InputDecoration(
            labelText: "Add a message (optional)",
            border: OutlineInputBorder(),
            hintText: "e.g. Please bring your previous reports."
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('appointments').doc(docId).update({
                'status': status,
                'doctorMessage': msgController.text,
                'processedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Appointment $status")));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
              foregroundColor: Colors.white
            ),
            child: Text("Confirm ${status == 'confirmed' ? 'Accept' : 'Reject'}"),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Diagnostic History",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => _clearCollection(context, 'diagnostic_reports'),
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: "Clear History",
              ),
            ],
          ),
          const Text("Past reports and uploads",
              style: TextStyle(color: Colors.grey)),
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
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    final results = data['results'] as Map<String, dynamic>? ?? {};
                    final timestamp =
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child:
                              const Icon(Icons.assignment, color: Colors.blue),
                        ),
                        title: Text(
                          data['patientName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            Text("Date: ${timestamp.toString().split('.')[0]}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                              onPressed: () => _showChatDialog(docs[index].id, data['patientName'] ?? 'Unknown'),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (data['status'] == 'reviewed')
                                    ? Colors.green.withAlpha(26)
                                    : Colors.orange.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data['status']?.toUpperCase() ?? 'PENDING',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: (data['status'] == 'reviewed')
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Vitals & Results:",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                                const SizedBox(height: 5),
                                ...results.entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e.key),
                                        Text(
                                          e.value.toString(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (data['prescription'] != null) ...[
                                  const Divider(),
                                  const Text("Doctor's Note:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue)),
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
      ),
    );
  }

  Future<void> _clearCollection(BuildContext context, String collectionPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All Records?"),
        content: const Text("This action cannot be undone. Are you sure you want to delete all records in this section?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final snapshot = await FirebaseFirestore.instance.collection(collectionPath).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All records cleared.")));
      }
    }
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          const Text("",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
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
                        final isMe = m['role'] == 'doctor';
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
                        'senderName': 'Dr. ${widget.session.username}',
                        'role': 'doctor',
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

  // ==== FIX 3: pass BuildContext so context is defined ====
  void _openPatientReview(
      String docId, Map<String, dynamic> data, BuildContext context) async {
    final TextEditingController prescriptionCtrl = TextEditingController();
    final results = data['results'] as Map<String, dynamic>? ?? {};
    final String name = data['patientName'] ?? 'Unknown';
    final String diagnosis = results['Diagnosis'] ?? 'No diagnosis';

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Review: $name"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "AI Insight: $diagnosis",
                              style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.red),
                      ...results.entries.map(
                        (e) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(fontSize: 13)),
                              Text(
                                e.value.toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Prescription / Advice:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: prescriptionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        "Enter medication, dosage, and instructions...",
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Calling PHC Worker...")),
              );
            },
            icon: const Icon(Icons.video_call),
            label: const Text("Video Call"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('diagnostic_reports')
                  .doc(docId)
                  .update({
                'status': 'reviewed',
                'prescription': prescriptionCtrl.text,
                'reviewedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Prescription Sent to PHC!")),
              );
            },
            child: const Text("Send Prescription"),
          ),
        ],
      ),
    );
    prescriptionCtrl.dispose();
  }
}
