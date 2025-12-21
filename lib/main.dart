import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase Initialized - New Build Running");
  } catch (e) {
    // This catches errors like missing platform config (Linux) or network issues
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(const HealthNexusApp());
}

class HealthNexusApp extends StatelessWidget {
  const HealthNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health_Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF3B82F6),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- Models ---
class UserSession {
  final String username;
  final String role;
  final String userId;
  final String name;
  final int age;
  final String gender;
  final String dob;
  final double weight;
  final double height;

  UserSession({
    required this.username,
    required this.role,
    required this.userId,
    this.name = '',
    this.age = 0,
    this.gender = 'Male',
    this.dob = '',
    this.weight = 70.0,
    this.height = 175.0,
  });
}

class HealthRecord {
  final String patientName;
  final String hr;
  final String spo2;
  final String status; // 'Normal', 'Critical', 'Warning'

  HealthRecord({
    required this.patientName,
    required this.hr,
    required this.spo2,
    required this.status,
  });
}

// --- Main Navigation Wrapper ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserSession? _session;
  bool _isLoggingIn = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _recoverSession();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _recoverSession() async {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && mounted) {
        await _setSessionFromUser(user);
      } else {
        if (mounted) setState(() => _session = null);
      }
    });
  }

  Future<void> _setSessionFromUser(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      
      if (mounted) {
        setState(() {
          _session = UserSession(
            userId: user.uid,
            username: user.email ?? '',
            role: data['role'] ?? 'patient',
            name: data['name'] ?? '',
            age: int.tryParse(data['age'].toString()) ?? 0,
            gender: data['gender'] ?? 'Male',
            dob: data['dob'] ?? '',
            weight: double.tryParse(data['weight'].toString()) ?? 70.0,
            height: double.tryParse(data['height'].toString()) ?? 175.0,
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  void _login(String email, String password, String role) async {
    setState(() => _isLoggingIn = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Listener in _recoverSession will handle state update
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException Code: ${e.code}");
      String msg = e.message ?? "Authentication failed";
      if (e.code == 'network-request-failed') {
        msg = "Network error: Check emulator internet or disable 'Email Enumeration Protection' in Firebase Console.";
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: $msg")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _register(Map<String, dynamic> data) async {
    setState(() => _isLoggingIn = true);
    try {
      // 1. Create Auth User
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: data['username'],
        password: data['password'],
      );

      // 2. Store Profile in Firestore
      if (credential.user != null) {
        final userData = Map<String, dynamic>.from(data);
        userData.remove('password'); // Don't store password in DB
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set(userData);
        
        // FIX: Force refresh session to ensure role/profile data is loaded correctly.
        // The authStateChanges listener might have fired before the Firestore write completed.
        if (mounted) {
          await _setSessionFromUser(credential.user!);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _forgotPassword(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter your email address above")));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password reset email sent")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginScreen(onLogin: _login, onRegister: _register, onForgotPassword: _forgotPassword, isLoading: _isLoggingIn);
    }
    
    return _session!.role == 'patient' 
        ? PatientDashboard(session: _session!, onLogout: _logout)
        : _session!.role == 'doctor'
            ? DoctorDashboard(session: _session!, onLogout: _logout)
            : HealthWorkerDashboard(session: _session!, onLogout: _logout);
  }
}

// --- 1. Login Screen ---
class LoginScreen extends StatefulWidget {
  final Function(String, String, String) onLogin;
  final Function(Map<String, dynamic>) onRegister;
  final Function(String) onForgotPassword;
  final bool isLoading;

  const LoginScreen({super.key, required this.onLogin, required this.onRegister, required this.onForgotPassword, required this.isLoading});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _degreeController = TextEditingController();
  final _specController = TextEditingController();
  final _expController = TextEditingController();
  
  String _selectedRole = 'patient';
  String _selectedGender = 'Male';
  bool _isRegistering = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              const Text(
                "HEALTH_NEXUS",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const Text("Unified Diagnostic Gateway", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 50),
              if (_isRegistering) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
              ),
              if (!_isRegistering)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => widget.onForgotPassword(_userController.text.trim()),
                    child: const Text("Forgot Password?"),
                  ),
                ),
              const SizedBox(height: 30),
              if (_isRegistering) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Age", prefixIcon: Icon(Icons.calendar_today)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(labelText: "Gender"),
                        items: ["Male", "Female", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _selectedGender = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _dobController,
                  decoration: const InputDecoration(labelText: "Date of Birth (YYYY-MM-DD)", prefixIcon: Icon(Icons.cake)),
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime(1990), firstDate: DateTime(1900), lastDate: DateTime.now());
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Weight (kg)"))),
                    const SizedBox(width: 15),
                    Expanded(child: TextField(controller: _heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Height (cm)"))),
                  ],
                ),
                const SizedBox(height: 30),
              ],
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: "Access Level"),
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text("Patient Portal")),
                  DropdownMenuItem(value: 'worker', child: Text("Health Worker / PHC")),
                  DropdownMenuItem(value: 'doctor', child: Text("Doctor Portal")),
                ],
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              if (_isRegistering && _selectedRole == 'doctor') ...[
                const SizedBox(height: 20),
                TextField(controller: _degreeController, decoration: const InputDecoration(labelText: "Degree (e.g., MBBS)", prefixIcon: Icon(Icons.school))),
                const SizedBox(height: 20),
                TextField(controller: _specController, decoration: const InputDecoration(labelText: "Specialization", prefixIcon: Icon(Icons.local_hospital))),
                const SizedBox(height: 20),
                TextField(controller: _expController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Experience (Years)", prefixIcon: Icon(Icons.work))),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: widget.isLoading ? null : () {
                    if (_isRegistering) {
                      final data = {
                        'username': _userController.text,
                        'password': _passController.text,
                        'role': _selectedRole,
                        'name': _nameController.text,
                        'age': _ageController.text,
                        'gender': _selectedGender,
                        'dob': _dobController.text,
                        'weight': _weightController.text,
                        'height': _heightController.text,
                      };
                      if (_selectedRole == 'doctor') {
                        data['degree'] = _degreeController.text;
                        data['specialization'] = _specController.text;
                        data['experience'] = _expController.text;
                      }
                      widget.onRegister(data);
                    } else {
                      widget.onLogin(_userController.text, _passController.text, _selectedRole);
                    }
                  },
                  child: widget.isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_isRegistering ? "Register & Login" : "Access System", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isRegistering = !_isRegistering),
                child: Text(_isRegistering ? "Already have an account? Login" : "Don't have an account? Register"),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// --- 2. Patient Dashboard ---
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
  
  // State for BMI Calculation
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
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.grey),
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
             ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text("Message"), onTap: (){}),
             ListTile(leading: const Icon(Icons.person_outline), title: const Text("Profile Settings"), onTap: () => setState(() { _selectedIndex = 3; Navigator.pop(context); })),
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
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully")));
                } catch (e) {
                  if (!context.mounted) return;
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
                // AI Shortcut Card
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 2), // Switch to AI Tab
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Theme.of(context).colorScheme.secondary, const Color(0xFF60A5FA)]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
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
        return const Center(child: Text("Chat Section"));
      case 4:
        return _buildProfileSection();
      default:
        return const SizedBox.shrink();
    }
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

  Widget _buildProfileSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildResponsiveContent(
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
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
                color: isSelected ? Colors.white.withOpacity(0.1) : bgColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : iconColor),
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
                painter: _ChartPainter(_vitalData[_selectedVital]!, graphColor),
              ),
            ),
          )
        ],
      ),
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
                      backgroundColor: isConfirmed ? const Color(0xFFE2F6ED) : const Color(0xFFFFF2D8),
                      child: Icon(Icons.calendar_today, color: isConfirmed ? const Color(0xFF28A745) : const Color(0xFFFFA000)),
                    ),
                    title: Text(isConfirmed ? "Appointment Confirmed" : "Request Pending", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isConfirmed ? "Doctor has accepted your request." : "Waiting for doctor approval."),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isConfirmed ? const Color(0xFFE2F6ED) : const Color(0xFFFFF2D8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(
                        fontSize: 12, 
                        color: isConfirmed ? const Color(0xFF28A745) : const Color(0xFFFFA000),
                        fontWeight: FontWeight.bold
                      )),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }


}

// --- 4. Doctor Dashboard ---
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
                  // Stats Row
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Total Patients", "${patients.length}", Icons.people, Colors.blue)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildStatCard("Appointments", "12", Icons.calendar_today, Colors.orange)),
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
                              // Live Vitals Preview
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)]),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
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

class DoctorPatientDetailScreen extends StatelessWidget {
  final String patientId;
  final Map<String, dynamic> data;

  const DoctorPatientDetailScreen({super.key, required this.patientId, required this.data});

  @override
  Widget build(BuildContext context) {
    final vitals = data['vitals'] as Map<String, dynamic>? ?? {};
    
    return Scaffold(
      appBar: AppBar(title: Text(data['name'] ?? "Patient Details")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Live Vitals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: vitals.entries.map((e) => Chip(
                label: Text("${e.key}: ${e.value}"),
                backgroundColor: Colors.blue.shade50,
              )).toList(),
            ),
            if (vitals.isEmpty) const Text("No live vitals available yet."),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat feature opening...")));
                },
                icon: const Icon(Icons.chat),
                label: const Text("Chat with Patient"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF09E5AB), foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _ChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Handle single data point to prevent division by zero or empty graph
    if (data.length == 1) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 5, Paint()..color = color);
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    double minVal = data.reduce((curr, next) => curr < next ? curr : next);
    double maxVal = data.reduce((curr, next) => curr > next ? curr : next);
    double range = maxVal - minVal;
    if (range == 0) range = 1;
    
    double stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double normalizedY = (data[i] - minVal) / range;
      double y = size.height * 0.9 - (normalizedY * size.height * 0.8);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
    
    // Fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
      
    canvas.drawPath(fillPath, fillPaint);

    // Dots
    final dotPaint = Paint()..color = const Color(0xFF0F172A);
    final dotBgPaint = Paint()..color = Colors.white;
    
    for (int i = 0; i < data.length; i++) {
       double x = i * stepX;
       double normalizedY = (data[i] - minVal) / range;
       double y = size.height * 0.9 - (normalizedY * size.height * 0.8);
       
       canvas.drawCircle(Offset(x, y), 6, dotBgPaint);
       canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.color != color;
}

// --- 3. Health Worker Dashboard ---
class HealthWorkerDashboard extends StatelessWidget {
  final UserSession session;
  final VoidCallback onLogout;

  HealthWorkerDashboard({super.key, required this.session, required this.onLogout});

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
        actions: [IconButton(onPressed: onLogout, icon: const Icon(Icons.logout))],
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
                      Color statusColor = p.status == 'Critical' ? Colors.red : (p.status == 'Warning' ? Colors.orange : Colors.green);
                      
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
                            // In a real app, navigate to patient detail view
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
        onPressed: () {},
        label: const Text("Sync All Nodes"),
        icon: const Icon(Icons.sync),
      ),
    );
  }
}
