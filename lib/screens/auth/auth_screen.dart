import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

class AuthScreen extends StatefulWidget {
  final Function(String, String, String) onLogin;
  final Function(Map<String, dynamic>) onRegister;
  final Function(String) onForgotPassword;
  final bool isLoading;

  const AuthScreen({
    super.key, 
    required this.onLogin,
    required this.onRegister,
    required this.onForgotPassword,
    required this.isLoading,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLogin = true;
  late AnimationController _bgController;
  late AnimationController _pulseController; // Controller for logo pulse
  late AnimationController _entryController; // Controller for form entry
  final List<String> _quotes = [
    "\"Bridging the gap between cities and villages.\"",
    "\"Quality healthcare, reaching the last mile.\"",
    "\"Empowering rural lives with digital health.\"",
    "\"Every life matters, everywhere.\"",
    "\"Smart diagnostics for a healthier tomorrow.\""
  ];
  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;

  // Controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    // Background Animation Loop
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Logo Pulse Animation (Healthcare heartbeat effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Form Entry Animation (Slide & Fade)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryController.forward();

    // Quote Rotation
    _quoteTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
      });
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    _quoteTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _degreeController.dispose();
    _specController.dispose();
    _expController.dispose();
    super.dispose();
  }

  void _handleAuth() {
    if (_isLogin) {
      widget.onLogin(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        'patient', // Role is ignored by Firebase login, but required by callback signature
      );
    } else {
      final data = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
        'name': _nameController.text.trim(),
        'age': _ageController.text.trim(),
        'gender': _selectedGender,
        'dob': _dobController.text.trim(),
        'weight': _selectedRole == 'patient' ? _weightController.text.trim() : '0',
        'height': _selectedRole == 'patient' ? _heightController.text.trim() : '0',
      };

      if (_selectedRole == 'doctor') {
        data['degree'] = _degreeController.text.trim();
        data['specialization'] = _specController.text.trim();
        data['experience'] = _expController.text.trim();
      }

      widget.onRegister(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Animated Background
          _buildAnimatedBackground(),
          
          // 2. Glassmorphism Content Overlay
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Enhanced Healthcare Logo Header
                  _buildHealthcareLogo(),
                  const SizedBox(height: 40),

                  // Auth Card
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
                      CurvedAnimation(parent: _entryController, curve: Curves.easeOut)
                    ),
                    child: FadeTransition(
                      opacity: _entryController,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 400,
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26), // ~10% opacity
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withAlpha(51)), // ~20% opacity
                            ),
                            child: Column(
                              children: [
                                // Login / Register Toggle
                                Row(
                                  children: [
                                    Expanded(child: _buildTab("Login", _isLogin)),
                                    Expanded(child: _buildTab("Register", !_isLogin)),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                
                                // Name Field (Register Only)
                                if (!_isLogin) ...[
                                  _buildTextField(Icons.badge_outlined, "Full Name", _nameController),
                                  const SizedBox(height: 15),
                                ],

                                // Input Fields
                                _buildTextField(Icons.email, "Email", _usernameController),
                                const SizedBox(height: 15),
                                _buildTextField(Icons.lock, "Password", _passwordController, isPassword: true),
                                
                                if (_isLogin)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => widget.onForgotPassword(_usernameController.text.trim()),
                                      child: const Text("Forgot Password?", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ),
                                  ),
                                
                                // Extended Registration Form
                                if (!_isLogin) ...[
                                  const SizedBox(height: 15),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedRole,
                                    dropdownColor: Colors.blueGrey.shade900,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration("Role", Icons.work),
                                    items: ['patient', 'doctor', 'worker'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                                    onChanged: (v) => setState(() => _selectedRole = v!),
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      Expanded(child: _buildTextField(Icons.calendar_today, "Age", _ageController, isNumber: true)),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedGender,
                                          dropdownColor: Colors.blueGrey.shade900,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: _inputDecoration("Gender", Icons.person),
                                          items: ["Male", "Female", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                          onChanged: (v) => setState(() => _selectedGender = v!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  TextField(
                                    controller: _dobController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration("Date of Birth", Icons.cake),
                                    readOnly: true,
                                    onTap: () async {
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime(1990),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF09E5AB),
                                                onPrimary: Colors.white,
                                                onSurface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        }
                                      );
                                      if (picked != null) {
                                        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
                                  if (_selectedRole == 'patient') ...[
                                    Row(
                                      children: [
                                        Expanded(child: _buildTextField(Icons.monitor_weight, "Weight (kg)", _weightController, isNumber: true)),
                                        const SizedBox(width: 15),
                                        Expanded(child: _buildTextField(Icons.height, "Height (cm)", _heightController, isNumber: true)),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                  
                                  if (_selectedRole == 'doctor') ...[
                                    _buildTextField(Icons.school, "Degree", _degreeController),
                                    const SizedBox(height: 15),
                                    _buildTextField(Icons.local_hospital, "Specialization", _specController),
                                    const SizedBox(height: 15),
                                    _buildTextField(Icons.work, "Experience (Years)", _expController, isNumber: true),
                                  ]
                                ],

                                const SizedBox(height: 30),
                                
                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: widget.isLoading ? null : _handleAuth,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF09E5AB),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 5,
                                      shadowColor: const Color(0xFF09E5AB).withAlpha(100),
                                    ),
                                    child: widget.isLoading 
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(
                                          _isLogin ? "LOGIN" : "CREATE ACCOUNT",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Animated Quotes Carousel
                  SizedBox(
                    height: 60,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(anim), child: child)),
                      child: Text(
                        _quotes[_currentQuoteIndex],
                        key: ValueKey<int>(_currentQuoteIndex),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthcareLogo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF09E5AB), Color(0xFF1B5A90)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF09E5AB).withOpacity(0.3 + (_pulseController.value * 0.2)),
                    blurRadius: 15 + (_pulseController.value * 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.05),
                child: const Icon(Icons.monitor_heart, size: 50, color: Colors.white),
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        const Text(
          "HEALTH NEXUS",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
          ),
        ),
        const Text(
          "Unified Diagnostic Gateway",
          style: TextStyle(color: Colors.white70, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0F172A), const Color(0xFF1B5A90), _bgController.value)!,
                Color.lerp(const Color(0xFF334155), const Color(0xFF09E5AB), _bgController.value)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -100 + (_bgController.value * 50),
                left: -100 + (_bgController.value * 100),
                child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF09E5AB).withAlpha(51), boxShadow: [BoxShadow(color: const Color(0xFF09E5AB).withAlpha(51), blurRadius: 100, spreadRadius: 20)])),
              ),
              Positioned(
                bottom: -100 - (_bgController.value * 50),
                right: -100 - (_bgController.value * 100),
                child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1B5A90).withAlpha(51), boxShadow: [BoxShadow(color: const Color(0xFF1B5A90).withAlpha(51), blurRadius: 100, spreadRadius: 20)])),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isLogin = label == "Login"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? const Color(0xFF09E5AB) : Colors.transparent, width: 3)),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildTextField(IconData icon, String hint, TextEditingController controller, {bool isPassword = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint, icon),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withAlpha(26),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF09E5AB))),
    );
  }
}