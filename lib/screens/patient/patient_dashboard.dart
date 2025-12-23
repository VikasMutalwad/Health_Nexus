import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health_nexus/widgets/chart_pointer.dart';
import '../../models/user_session.dart';
import '../../widgets/stat_card.dart';

class PatientDashboard extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const PatientDashboard({super.key, required this.session, required this.onLogout});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
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
  }

  @override
  void dispose() {
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
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
            onPressed: () {},
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
               accountEmail: const Text("Patient Portal"),
               currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Color(0xFF09E5AB))),
             ),
             ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () => setState(() { _selectedIndex = 0; Navigator.pop(context); })),
             ListTile(leading: const Icon(Icons.person_outline), title: const Text("Profile Settings"), onTap: () => setState(() { _selectedIndex = 3; Navigator.pop(context); })),
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildHomeTab();
      case 1: return const Center(child: Text("Appointments Section"));
      case 2: return const Center(child: Text("AI Section"));
      case 3: return _buildProfileSection();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildHomeTab() {
     // BMI Calculation
    double bmi = 0.0;
    if (_height > 0) {
      double heightInMeters = _height / 100.0;
      bmi = _weight / (heightInMeters * heightInMeters);
    }

    return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildAIPreviewCard(),
               const SizedBox(height: 25),
               // REPLACED OLD CARD LOGIC WITH NEW WIDGET
               Row(
                 children: [
                   Expanded(child: StatCard(
                     title: "Heart Rate", 
                     value: _vitalData['Heart Rate']!.last.toStringAsFixed(0), 
                     unit: "bpm", 
                     icon: Icons.favorite, 
                     bgColor: const Color(0xFFDAF2FE), 
                     iconColor: const Color(0xFF1B5A90),
                     isSelected: _selectedVital == "Heart Rate",
                     onTap: () => setState(() => _selectedVital = "Heart Rate"),
                   )),
                   const SizedBox(width: 15),
                   Expanded(child: StatCard(
                     title: "Body Temp", 
                     value: _vitalData['Body Temp']!.last.toStringAsFixed(1), 
                     unit: "°C", 
                     icon: Icons.thermostat, 
                     bgColor: const Color(0xFFFFF2D8), 
                     iconColor: const Color(0xFFFFA000),
                     isSelected: _selectedVital == "Body Temp",
                     onTap: () => setState(() => _selectedVital = "Body Temp"),
                   )),
                 ],
               ),
               const SizedBox(height: 15),
               Row(
                 children: [
                   Expanded(child: StatCard(
                     title: "SpO2", 
                     value: _vitalData['SpO2']!.last.toStringAsFixed(0), 
                     unit: "%", 
                     icon: Icons.air, 
                     bgColor: const Color(0xFFE0F7FA), 
                     iconColor: const Color(0xFF00BCD4),
                     isSelected: _selectedVital == "SpO2",
                     onTap: () => setState(() => _selectedVital = "SpO2"),
                   )),
                   const SizedBox(width: 15),
                   Expanded(child: StatCard(
                     title: "Blood Pressure", 
                     value: _vitalData['Blood Pressure']!.last.toStringAsFixed(0), 
                     unit: "mmHg", 
                     icon: Icons.monitor_heart, 
                     bgColor: const Color(0xFFE6FFFA), 
                     iconColor: const Color(0xFF09E5AB),
                     isSelected: _selectedVital == "Blood Pressure",
                     onTap: () => setState(() => _selectedVital = "Blood Pressure"),
                   )),
                 ],
               ),
               const SizedBox(height: 25),
               Text("$_selectedVital Analysis", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 15),
               _buildGraphCard(),
            ],
          ),
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
              const Text("Last 7 Days", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                // USING THE NEW WIDGET
                painter: ChartPainter(_vitalData[_selectedVital]!, graphColor),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAIPreviewCard() {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Theme.of(context).colorScheme.secondary, const Color(0xFF60A5FA)]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
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
    );
  }

  Widget _buildProfileSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () async {
               // Update logic here
            },
            child: const Text("Save Changes"),
          )
        ],
      ),
    );
  }

  Color _getVitalColor(String vital) {
    switch (vital) {
      case 'Heart Rate': return const Color(0xFF1B5A90);
      case 'Body Temp': return const Color(0xFFFFA000);
      case 'SpO2': return const Color(0xFF00BCD4);
      case 'Blood Pressure': return const Color(0xFF09E5AB);
      default: return const Color(0xFF09E5AB);
    }
  }
}