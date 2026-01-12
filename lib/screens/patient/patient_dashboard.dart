import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:health_nexus/widgets/chart_pointer.dart';
import '../../models/user_session.dart';

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

  // AI Assistant
  final TextEditingController _aiController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, String>> _aiMessages = [];
  bool _isAiLoading = false;
  static const String _geminiApiKey = 'AIzaSyD6IKh5Cc7jR9SrD184Qo9PnmyiJCdfN0M'; // TODO: Insert your API Key here

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
    _setupPushNotifications();
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _aiController.dispose();
    _nameController.dispose(); _ageController.dispose();
    _weightController.dispose(); _heightController.dispose(); _dobController.dispose();
    super.dispose();
  }

  Future<void> _setupPushNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request permission for notifications
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token and save to user profile
        String? token = await messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(widget.session.userId).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
        }

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Reminder: ${message.notification!.title}"),
              action: SnackBarAction(label: "View", onPressed: _showNotifications),
            ));
          }
        });
      }
    } catch (e) {
      debugPrint("Error setting up notifications: $e");
    }
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
             ListTile(leading: const Icon(Icons.history), title: const Text("Past Visit Reports"), onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (context) => PastVisitReportsScreen(userId: widget.session.userId)));
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

  Widget _buildResponsiveContent({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: child,
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
                Text("Health Score (Last Visit)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text("Based on report from Oct 24, 2023", style: TextStyle(color: Colors.white70, fontSize: 13)),
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
            const Text("Last Visit Report", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("Oct 24, 2023", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
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
                onTap: _showImageSourceDialog,
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
                    child: _aiMessages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 60, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(height: 20),
                                const Text("How can I help you today?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _aiMessages.length,
                            itemBuilder: (context, index) {
                              final msg = _aiMessages[index];
                              final isUser = msg['role'] == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isUser ? Theme.of(context).colorScheme.secondary : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12).copyWith(
                                      bottomRight: isUser ? Radius.zero : null,
                                      bottomLeft: !isUser ? Radius.zero : null,
                                    ),
                                  ),
                                  child: Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aiController,
                          onSubmitted: (_) => _sendMessage(),
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
                        child: IconButton(
                          icon: _isAiLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
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

  Future<void> _sendMessage() async {
    final text = _aiController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _aiMessages.add({'role': 'user', 'text': text});
      _isAiLoading = true;
    });
    _aiController.clear();

    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _geminiApiKey);
      
      // Construct history for the chat session to maintain context
      final List<Content> history = _aiMessages
          .take(_aiMessages.length - 1)
          .map((m) => m['role'] == 'user' 
              ? Content.text(m['text']!) 
              : Content.model([TextPart(m['text']!)]))
          .toList();

      final chat = model.startChat(history: history);

      final prompt = '''
You are HealthNexus AI, a helpful medical assistant.
Current Patient Context:
- Profile: Age ${_ageController.text}, Gender $_gender, Weight $_weight kg
- Vitals: $_vitalData

User Question: $text

Provide a concise, safe, and helpful medical response regarding health, symptoms, remedies, diagnostics, or nutrition. If the question is about the vitals provided, analyze them. Always advise consulting a doctor for serious issues.
''';

      final response = await chat.sendMessage(Content.text(prompt));

      setState(() => _aiMessages.add({'role': 'ai', 'text': response.text ?? "No response generated."}));
    } catch (e) {
      setState(() => _aiMessages.add({'role': 'ai', 'text': "Error: $e"}));
    } finally {
      setState(() => _isAiLoading = false);
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndAnalyzeImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndAnalyzeImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _aiMessages.add({'role': 'user', 'text': "📄 Analyzing attached lab report..."});
        _isAiLoading = true;
      });

      final bytes = await image.readAsBytes();
      // Use gemini-pro-vision for vision capabilities
      final model = GenerativeModel(model: 'gemini-pro-vision', apiKey: _geminiApiKey);
      
      final prompt = TextPart("Analyze this medical lab report image. Extract key values, identify any abnormal results, and provide a brief summary of what they mean in simple terms. If the image is not a lab report, please state that.");
      final imagePart = DataPart('image/jpeg', bytes);

      final content = [Content.multi([prompt, imagePart])];
      final response = await model.generateContent(content);

      setState(() => _aiMessages.add({'role': 'ai', 'text': response.text ?? "Analysis failed."}));
    } catch (e) {
      setState(() => _aiMessages.add({'role': 'ai', 'text': "Error analyzing image: $e"}));
    } finally {
      setState(() => _isAiLoading = false);
    }
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
            onPressed: _showBookAppointmentDialog,
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
                
                final type = data['type'] ?? 'Clinic Visit';
                final Timestamp? apptTimestamp = data['appointmentDate'];
                final apptDate = apptTimestamp?.toDate();
                final dateStr = apptDate != null 
                    ? "${apptDate.day}/${apptDate.month} ${apptDate.hour.toString().padLeft(2,'0')}:${apptDate.minute.toString().padLeft(2,'0')}" 
                    : "Date Pending";

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
                      child: Icon(type == 'Video Call' ? Icons.videocam : (type == 'Audio Call' ? Icons.call : (type == 'Chat' ? Icons.chat : Icons.calendar_today)), color: statusColor),
                    ),
                    title: Text(
                      "$type ($dateStr)", 
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

  void _showBookAppointmentDialog() {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String selectedType = 'Clinic Visit';
    final List<String> appointmentTypes = ['Clinic Visit', 'Home Visit', 'Video Call', 'Audio Call', 'Chat'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Book Appointment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Date & Time", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (date != null) setState(() => selectedDate = date);
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(selectedDate == null ? "Date" : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}", style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (time != null) setState(() => selectedTime = time);
                          },
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(selectedTime == null ? "Time" : selectedTime!.format(context), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Appointment Type", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                    items: appointmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select date and time")));
                      return;
                    }
                    final DateTime appointmentDateTime = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
                    Map<String, dynamic> currentVitals = {};
                    _vitalData.forEach((k, v) { if(v.isNotEmpty) currentVitals[k] = v.last; });

                    await FirebaseFirestore.instance.collection('appointments').add({
                      'patientId': widget.session.userId,
                      'patientName': widget.session.name.isNotEmpty ? widget.session.name : widget.session.username,
                      'status': 'pending',
                      'requestDate': FieldValue.serverTimestamp(),
                      'appointmentDate': Timestamp.fromDate(appointmentDateTime),
                      'type': selectedType,
                      'vitals': currentVitals,
                    });
                    if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment Request Sent"))); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09E5AB), foregroundColor: Colors.white),
                  child: const Text("Book"),
                ),
              ],
            );
          }
        );
      },
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

class PastVisitReportsScreen extends StatelessWidget {
  final String userId;
  const PastVisitReportsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Past Visit Reports", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('visit_reports')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text("No reports available", style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
              final doctorName = data['doctorName'] ?? 'General Practitioner';
              final diagnosis = data['diagnosis'] ?? 'Regular Checkup';
              final hospital = data['hospital'] ?? 'Health Nexus Clinic';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${date.day}/${date.month}/${date.year}",
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("Completed", style: TextStyle(color: Color(0xFF0288D1), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(diagnosis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Dr. $doctorName • $hospital", style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 16),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading PDF Report...")));
                            },
                            icon: const Icon(Icons.download_rounded, size: 20),
                            label: const Text("Download PDF"),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF09E5AB)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}