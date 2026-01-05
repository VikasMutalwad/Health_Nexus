import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health_nexus/widgets/chart_pointer.dart';
import '../../models/user_session.dart';
import 'dart:math';

class PatientDashboard extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const PatientDashboard({super.key, required this.session, required this.onLogout});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _selectedVital = 'Heart Rate';
  
  // Profile Controllers
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _dobController;
  
  double _weight = 70.0;
  double _height = 175.0;
  String _gender = "Male";

  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  final Map<String, List<double>> _vitalData = {
    'Heart Rate': [72, 75, 76, 78, 74, 72, 73],
    'Body Temp': [36.6, 36.7, 36.8, 37.0, 36.9, 36.7, 36.6],
    'Glucose': [92, 95, 98, 94, 90, 88, 91],
    'Blood Pressure': [118, 120, 122, 119, 121, 123, 120],
    'SpO2': [96, 97, 98, 96, 97, 98, 99],
    'ECG Status': [1, 1, 1, 1, 1, 1, 1],
    'Hemoglobin': [12.5, 12.8, 13.0, 13.2, 13.1, 13.0, 13.2],
    'Protein Level': [0, 0, 0, 1, 0, 0, 0],
    'pH Level': [6.0, 6.2, 5.8, 6.0, 6.5, 6.0, 6.2],
    'BMI': [22.5, 22.6, 22.7, 22.8, 22.7, 22.6, 22.8],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name.isNotEmpty ? widget.session.name : widget.session.username);
    _ageController = TextEditingController(text: (widget.session.age > 0 ? widget.session.age : 30).toString());
    _weightController = TextEditingController(text: widget.session.weight.toString());
    _heightController = TextEditingController(text: widget.session.height.toString());
    _dobController = TextEditingController(text: widget.session.dob);

    _weight = widget.session.weight;
    _height = widget.session.height;
    _gender = widget.session.gender;
    _syncMockVitals();

    _heartbeatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _nameController.dispose(); _ageController.dispose();
    _weightController.dispose(); _heightController.dispose(); _dobController.dispose();
    super.dispose();
  }

  void _syncMockVitals() {
    try {
      Map<String, dynamic> latest = {};
      _vitalData.forEach((key, value) {
        if (value.isNotEmpty) latest[key] = value.last;
      });
      FirebaseFirestore.instance.collection('users').doc(widget.session.userId).set({
        'vitals': latest,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing vitals: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Dashboard", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.red, size: 30),
            onPressed: _triggerSOS,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
            onPressed: _showNotifications,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.person, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
             UserAccountsDrawerHeader(
               decoration: const BoxDecoration(color: Color(0xFF09E5AB)),
               accountName: Text(widget.session.username),
               accountEmail: const Text("Patient ID: P-001"),
               currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Color(0xFF09E5AB))),
             ),
             ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () => setState(() { _selectedIndex = 0; Navigator.pop(context); })),
             ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text("Message"), onTap: () {
               setState(() => _selectedIndex = 3);
               Navigator.pop(context);
             }),
             ListTile(leading: const Icon(Icons.history), title: const Text("AI Scan History"), onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (context) => AIScanHistoryScreen(userId: widget.session.userId)));
             }),
             ListTile(leading: const Icon(Icons.person_outline), title: const Text("Profile Settings"), onTap: () => setState(() { _selectedIndex = 4; Navigator.pop(context); })),
             ListTile(leading: const Icon(Icons.lock_outline), title: const Text("Change Password"), onTap: _showChangePasswordDialog),
             const Divider(),
             ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout", style: TextStyle(color: Colors.red)), onTap: widget.onLogout),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        selectedItemColor: const Color(0xFF09E5AB),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Appts"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AI Health"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton.extended(
        onPressed: _startAIScan,
        backgroundColor: const Color(0xFF09E5AB),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text("AI Scan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("EMERGENCY SOS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
        content: const Text("Sending your live location and vitals to emergency contacts and nearest ambulance service..."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS Signal Sent! Help is on the way."), backgroundColor: Colors.red));
            },
            child: const Text("CONFIRM SOS"),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.calendar_today, color: Colors.white, size: 20)),
              title: const Text("Appointment Confirmed"),
              subtitle: const Text("Dr. Smith confirmed your slot for tomorrow."),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white, size: 20)),
              title: const Text("High Heart Rate Alert"),
              subtitle: const Text("Your heart rate spiked to 105 bpm at 2 PM."),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Scan to Link Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            Container(
              width: 200, height: 200,
              color: Colors.black,
              child: const Center(child: Icon(Icons.qr_code_2, color: Colors.white, size: 150)),
            ),
            const SizedBox(height: 20),
            Text("ID: ${widget.session.userId}", style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  void _showChangePasswordDialog() {
    Navigator.pop(context); // Close drawer
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New Password"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.isNotEmpty) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  await user?.updatePassword(passController.text);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully")));
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  void _startAIScan() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Scan",      barrierColor: Colors.black.withAlpha(230),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const _AIScanOverlay(),
    ).then((result) async {
      if (result != null && result is Map<String, double>) {
        // Save to Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.session.userId)
              .collection('scan_history')
              .add({
            'timestamp': FieldValue.serverTimestamp(),
            'vitals': result,
          });
        } catch (e) {
          debugPrint("Error saving scan history: $e");
        }

        setState(() {
          _vitalData['Heart Rate']?.add(result['Heart Rate']!);
          _vitalData['SpO2']?.add(result['SpO2']!);
          _vitalData['Body Temp']?.add(result['Body Temp']!);
          _vitalData['Blood Pressure']?.add(result['Blood Pressure']!);
          
          // Keep list size manageable
          if (_vitalData['Heart Rate']!.length > 20) {
             _vitalData.forEach((key, list) {
               if (list.isNotEmpty) list.removeAt(0);
             });
          }
        });
        _syncMockVitals();
        // Show AI Analysis Report instead of just a snackbar
        _showAIAnalysisDialog(result);
      }
    });
  }

  Widget _buildResponsiveContent({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: child,
      ),
    );
  }

  void _showAIAnalysisDialog(Map<String, double> vitals) {
    List<Map<String, dynamic>> analysis = [];

    // Temperature Analysis
    double temp = vitals['Body Temp']!;
    if (temp > 37.5) {
      analysis.add({
        'vital': 'Body Temperature',
        'value': '${temp.toStringAsFixed(1)} °C',
        'status': 'High (Fever)',
        'color': Colors.red,
        'illness': 'Pyrexia (Fever)',
        'reasons': ['Viral Infection', 'Bacterial Infection', 'Heat Exhaustion'],
        'remedies': ['Stay Hydrated', 'Rest', 'Cool Compresses'],
        'medications': ['Paracetamol (Dolo 650)', 'Ibuprofen']
      });
    }

    // Heart Rate Analysis
    double hr = vitals['Heart Rate']!;
    if (hr > 100) {
      analysis.add({
        'vital': 'Heart Rate',
        'value': '${hr.toStringAsFixed(0)} bpm',
        'status': 'High (Tachycardia)',
        'color': Colors.red,
        'illness': 'Tachycardia',
        'reasons': ['Stress/Anxiety', 'Physical Exertion', 'Caffeine'],
        'remedies': ['Deep Breathing', 'Meditation', 'Reduce Caffeine'],
        'medications': ['Beta-blockers (Consult Doctor)']
      });
    }

    // BP Analysis
    double bp = vitals['Blood Pressure']!;
    if (bp > 130) {
      analysis.add({
        'vital': 'Blood Pressure',
        'value': '${bp.toStringAsFixed(0)} mmHg',
        'status': 'High (Hypertension)',
        'color': Colors.red,
        'illness': 'Hypertension',
        'reasons': ['High Sodium Diet', 'Stress', 'Lack of Activity'],
        'remedies': ['Low Sodium Diet', 'Exercise', 'Stress Management'],
        'medications': ['Amlodipine', 'Telmisartan (Consult Doctor)']
      });
    }

    // SpO2 Analysis
    double spo2 = vitals['SpO2']!;
    if (spo2 < 95) {
      analysis.add({
        'vital': 'SpO2',
        'value': '${spo2.toStringAsFixed(0)} %',
        'status': 'Low (Hypoxia)',
        'color': Colors.red,
        'illness': 'Hypoxia / Respiratory Issue',
        'reasons': ['Respiratory Infection', 'Asthma', 'High Altitude'],
        'remedies': ['Deep Breathing', 'Upright Posture', 'Fresh Air'],
        'medications': ['Inhalers (if prescribed)', 'Oxygen Therapy']
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            const Text("AI Health Analysis", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Based on your recent scan", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            if (analysis.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 80),
                      const SizedBox(height: 20),
                      const Text("All Vitals Normal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text("You are in great shape! Keep it up.", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 30),
                      ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: analysis.length,
                  itemBuilder: (context, index) {
                    final item = analysis[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withAlpha(13),
                        border: Border.all(color: (item['color'] as Color).withAlpha(77)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['vital'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: item['color'], borderRadius: BorderRadius.circular(20)),
                                child: Text(item['status'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text("Measured: ${item['value']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          if (item['illness'] != null) ...[
                            const Text("Potential Indication:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            Text(item['illness'], style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 10),
                          ],
                          const Text("Possible Reasons:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          Wrap(
                            spacing: 5,
                            children: (item['reasons'] as List<String>).map((r) => Chip(label: Text(r, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)).toList(),
                          ),
                          const SizedBox(height: 10),
                          const Text("Suggested Remedies:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: (item['remedies'] as List<String>).map((r) => Text("• $r", style: const TextStyle(fontSize: 13))).toList(),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.medication, color: Colors.blue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Suggested OTC Meds:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text((item['medications'] as List<String>).join(", "), style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Acknowledge & Save"),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHealthScoreSection(),
                _buildMedicationSection(),
                // AI Shortcut Card
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 2), // Switch to AI Tab
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(                      gradient: LinearGradient(colors: [Theme.of(context).colorScheme.secondary, const Color(0xFF60A5FA)]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.blue.withAlpha(77), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                        SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("AI Health Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text("Ask about your symptoms or vitals", style: TextStyle(color: Colors.white70, fontSize: 12))])),
                        Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16)
                      ],
                    ),
                  ),
                ),
                _buildStatsSection(),
                const SizedBox(height: 25),
                Text("$_selectedVital Analysis", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildGraphCard(),
                _buildDietSection(),
              ],
            ),
          ),
        );
      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Appointments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildAppointmentsList(),
              ],
            ),
          ),
        );
      case 2:
        return _buildAISection();
      case 3:
        return _buildChatSection();
      case 4:
        return _buildProfileSection();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildHealthScoreSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(            color: const Color(0xFF0F172A).withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              children: [
                const Center(
                  child: SizedBox(
                    height: 80,
                    width: 80,
                    child: CircularProgressIndicator(
                      value: 0.85,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF09E5AB)),
                    ),
                  ),
                ),
                const Center(
                  child: Text("85", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Health Score: Excellent", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text("Your vitals are stable. Keep up the good work!", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Daily Medications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Icon(Icons.medication, color: Color(0xFF09E5AB)),
            ],
          ),
          const SizedBox(height: 10),
          _buildMedTile("Metformin", "500mg", "Morning (After Food)", true),
          _buildMedTile("Atorvastatin", "10mg", "Night (Before Sleep)", false),
        ],
      ),
    );
  }

  Widget _buildMedTile(String name, String dose, String time, bool taken) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: taken ? Colors.green.shade100 : Colors.orange.shade100,
        child: Icon(taken ? Icons.check : Icons.access_time, color: taken ? Colors.green : Colors.orange, size: 20),
      ),
      title: Text(name, style: TextStyle(decoration: taken ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w500)),
      subtitle: Text("$dose • $time", style: const TextStyle(fontSize: 12)),
      trailing: Checkbox(
        value: taken, 
        activeColor: const Color(0xFF09E5AB),
        onChanged: (v) {},
      ),
    );
  }

  Widget _buildDietSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("AI Nutrition Plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Icon(Icons.restaurant_menu, color: Colors.orange),
            ],
          ),
          const SizedBox(height: 15),
          _buildDietItem("Breakfast", "Oatmeal with berries", "350 kcal"),
          const Divider(),
          _buildDietItem("Lunch", "Grilled Chicken Salad", "450 kcal"),
          const Divider(),
          _buildDietItem("Dinner", "Steamed Vegetables & Fish", "300 kcal"),
        ],
      ),
    );
  }

  Widget _buildDietItem(String meal, String food, String cal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meal, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            Text(food, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        Text(cal, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ],
    );
  }

  Widget _buildChatSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Messages", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE0F2FE),
                      child: const Icon(Icons.person, color: Color(0xFF0288D1)),
                    ),
                    title: Text("Dr. Specialist ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("How are you feeling today?"),
                    trailing: Text("10:${30 + index} AM", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Chat feature opening..."),
                        duration: Duration(seconds: 1),
                      ));
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    // BMI Calculation: Weight (kg) / (Height (m))^2
    // We convert height from cm to m by dividing by 100.
    double bmi = 0.0;
    if (_height > 0) {
      double heightInMeters = _height / 100.0;
      bmi = _weight / (heightInMeters * heightInMeters);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Live Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing with Wearable Device..."))),
              icon: const Icon(Icons.watch, size: 16),
              label: const Text("Sync Wearable"),
            )
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard("Heart Rate", _vitalData['Heart Rate']!.last.toStringAsFixed(0), "bpm", Icons.favorite, const Color(0xFFDAF2FE), const Color(0xFF1B5A90))),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard("Body Temp", _vitalData['Body Temp']!.last.toStringAsFixed(1), "°C", Icons.thermostat, const Color(0xFFFFF2D8), const Color(0xFFFFA000))),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildStatCard("SpO2", _vitalData['SpO2']!.last.toStringAsFixed(0), "%", Icons.air, const Color(0xFFE0F7FA), const Color(0xFF00BCD4))),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard("ECG Status", _vitalData['ECG Status']!.last == 1 ? "Normal" : "Abnormal", "", Icons.monitor_heart_outlined, const Color(0xFFF3E5F5), const Color(0xFF9C27B0))),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildStatCard("Glucose", _vitalData['Glucose']!.last.toStringAsFixed(0), "mg/dl", Icons.water_drop, const Color(0xFFFFEAEA), const Color(0xFFFF5353))),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard("Hemoglobin", _vitalData['Hemoglobin']!.last.toStringAsFixed(1), "g/dL", Icons.bloodtype, const Color(0xFFFFEBEE), const Color(0xFFE91E63))),
          ],
        ),
        const SizedBox(height: 15),
        _buildStatCard("Blood Pressure", _vitalData['Blood Pressure']!.last.toStringAsFixed(0), "mmHg", Icons.monitor_heart, const Color(0xFFE6FFFA), const Color(0xFF09E5AB)),
        const SizedBox(height: 25),
        const Text("Urine Dipstick Test", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildStatCard("Protein Level", _vitalData['Protein Level']!.last == 0 ? "Neg" : "Pos", "", Icons.science, const Color(0xFFF1F8E9), const Color(0xFF8BC34A))),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard("pH Level", _vitalData['pH Level']!.last.toStringAsFixed(1), "", Icons.opacity, const Color(0xFFFFF3E0), const Color(0xFFFF9800))),
          ],
        ),
        const SizedBox(height: 25),
        const Text("Body Composition", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildStatCard("BMI", bmi.toStringAsFixed(1), "kg/m²", Icons.monitor_weight, const Color(0xFFE1F5FE), const Color(0xFF0288D1)),
      ],
    );
  }

  Widget _buildGraphCard() {
    Color graphColor = _getVitalColor(_selectedVital);
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$_selectedVital Trends", style: const TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: "Last 7 Days",
                underline: Container(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                items: const [DropdownMenuItem(value: "Last 7 Days", child: Text("Last 7 Days"))],
                onChanged: (v) {},
              )
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                painter: ChartPainter(_vitalData[_selectedVital]!, graphColor),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAISection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Health Assistant", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Ask questions about your vitals or symptoms.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            // Lab Report OCR Card
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo.shade100)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.document_scanner, color: Colors.white)),
                title: const Text("Analyze Lab Report", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Upload a photo of your report for AI analysis."),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening Camera for OCR...")));
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 400,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 60, color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(height: 20),
                          const Text("How can I help you today?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Type your health question...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () {}),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildResponsiveContent(
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _showQRCode,
              icon: const Icon(Icons.qr_code),
              label: const Text("Show Health ID"),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    items: ["Male", "Female", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _gender = v!),
                    decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _dobController,
              decoration: const InputDecoration(labelText: "Date of Birth", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
                if (picked != null) {
                   _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}";
                   final now = DateTime.now();
                   int age = now.year - picked.year;
                   if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
                     age--;
                   }
                   _ageController.text = age.toString();
                }
              },
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _weight = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _height = double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('users').doc(widget.session.userId).update({
                    'name': _nameController.text,
                    'age': int.tryParse(_ageController.text) ?? 0,
                    'gender': _gender,
                    'dob': _dobController.text,
                    'weight': double.tryParse(_weightController.text) ?? 0,
                    'height': double.tryParse(_heightController.text) ?? 0,
                  });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated")));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF09E5AB), foregroundColor: Colors.white),
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon, Color bgColor, Color iconColor) {
    final isSelected = _selectedVital == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedVital = title),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, spreadRadius: 1)],
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withAlpha(26) : bgColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: title == 'Heart Rate'
                  ? ScaleTransition(scale: _heartbeatAnimation, child: Icon(icon, color: isSelected ? Colors.white : iconColor))
                  : Icon(icon, color: isSelected ? Colors.white : iconColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, color: isSelected ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
                      const SizedBox(width: 4),
                      Text(unit, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              // Create a request
              Map<String, dynamic> currentVitals = {};
              _vitalData.forEach((k, v) { if(v.isNotEmpty) currentVitals[k] = v.last; });
              
              await FirebaseFirestore.instance.collection('appointments').add({
                'patientId': widget.session.userId,
                'patientName': widget.session.name.isNotEmpty ? widget.session.name : widget.session.username,
                'status': 'pending',
                'requestDate': FieldValue.serverTimestamp(),
                'vitals': currentVitals,
              });
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment Request Sent to Doctors")));
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text("Book New Appointment"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09E5AB), foregroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('appointments').where('patientId', isEqualTo: widget.session.userId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Text("No appointments booked yet.");

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                final isConfirmed = status == 'confirmed';
                final isRejected = status == 'rejected';
                final doctorMessage = data['doctorMessage'];

                Color statusColor = isConfirmed ? const Color(0xFF28A745) : (isRejected ? Colors.red : const Color(0xFFFFA000));
                Color bgColor = isConfirmed ? const Color(0xFFE2F6ED) : (isRejected ? Colors.red.shade50 : const Color(0xFFFFF2D8));
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: bgColor,
                      child: Icon(Icons.calendar_today, color: statusColor),
                    ),
                    title: Text(
                      isConfirmed ? "Appointment Confirmed" : (isRejected ? "Appointment Rejected" : "Request Pending"), 
                      style: const TextStyle(fontWeight: FontWeight.bold)
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isConfirmed 
                          ? "Doctor has accepted your request." 
                          : (isRejected ? "Doctor has declined this request." : "Waiting for doctor approval.")
                        ),
                        if (doctorMessage != null && doctorMessage.toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text("Note: $doctorMessage", style: const TextStyle(color: Colors.black87, fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(
                        fontSize: 12, 
                        color: statusColor,
                        fontWeight: FontWeight.bold
                      )),
                    ),
                    onTap: isConfirmed ? () {
                      // Video Call Logic
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Start Telemedicine Call"),
                          content: const Text("Connecting to secure video channel..."),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("End Call"))],
                        ),
                      );
                    } : null,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Color _getVitalColor(String vital) {
    switch (vital) {
      case 'Heart Rate': return const Color(0xFF1B5A90);
      case 'Body Temp': return const Color(0xFFFFA000);
      case 'Glucose': return const Color(0xFFFF5353);
      case 'Blood Pressure': return const Color(0xFF09E5AB);
      case 'SpO2': return const Color(0xFF00BCD4);
      case 'ECG Status': return const Color(0xFF9C27B0);
      case 'Hemoglobin': return const Color(0xFFE91E63);
      case 'Protein Level': return const Color(0xFF8BC34A);
      case 'pH Level': return const Color(0xFFFF9800);
      case 'BMI': return const Color(0xFF0288D1);
      default: return const Color(0xFF09E5AB);
    }
  }
}

class _AIScanOverlay extends StatefulWidget {
  const _AIScanOverlay();

  @override
  State<_AIScanOverlay> createState() => _AIScanOverlayState();
}

class _AIScanOverlayState extends State<_AIScanOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _statusText = "Initializing Camera...";
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _startScanSequence();
  }

  void _startScanSequence() async {
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(() => _statusText = "Detecting Face...");
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(() => _statusText = "Scanning Heart Rate (PPG)...");
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(() => _statusText = "Analyzing SpO2 Levels...");
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(() => _statusText = "Measuring Body Temperature...");
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(() => _statusText = "Estimating Blood Pressure...");
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(() => _statusText = "Finalizing Health Analysis...");
    await Future.delayed(const Duration(seconds: 1));
    
    if(mounted) {
      final random = Random();
      Navigator.pop(context, {
        'Heart Rate': 60.0 + random.nextInt(50),
        'SpO2': 93.0 + random.nextInt(7),
        'Body Temp': 36.0 + (random.nextDouble() * 2.5),
        'Blood Pressure': 110.0 + random.nextInt(35),
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF09E5AB), width: 2),
                borderRadius: BorderRadius.circular(20),
                color: Colors.black26,                boxShadow: [BoxShadow(color: const Color(0xFF09E5AB).withAlpha(51), blurRadius: 20, spreadRadius: 5)],
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.face_retouching_natural, size: 180, color: Colors.white12)),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Positioned(
                        top: _controller.value * 260,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF09E5AB),                            boxShadow: [BoxShadow(color: const Color(0xFF09E5AB).withAlpha(204), blurRadius: 10, spreadRadius: 2)],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(_statusText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 20),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(color: Color(0xFF09E5AB), backgroundColor: Colors.white12),
            ),
          ],
        ),
      ),
    );
  }
}

class AIScanHistoryScreen extends StatelessWidget {
  final String userId;
  const AIScanHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Scan History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('scan_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No scan history found."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final vitals = data['vitals'] as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ExpansionTile(
                  title: Text("Scan: ${timestamp.toString().split('.')[0]}"),
                  subtitle: Text("HR: ${vitals['Heart Rate']?.toStringAsFixed(0)} bpm | Temp: ${vitals['Body Temp']?.toStringAsFixed(1)} °C"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: vitals.entries.map((e) => Column(
                          children: [
                            Text(e.key, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(e.value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )).toList(),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}