import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final Function(String, String, String) onLogin;
  final Function(Map<String, dynamic>) onRegister;
  final Function(String) onForgotPassword;
  final bool isLoading;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    required this.onForgotPassword,
    required this.isLoading,
  });

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
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1),
                ),
                const Text("Unified Diagnostic Gateway",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 50),
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.badge_outlined)),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(
                      labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline)),
                ),
                if (!_isRegistering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          widget.onForgotPassword(_userController.text.trim()),
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
                          decoration: const InputDecoration(
                              labelText: "Age",
                              prefixIcon: Icon(Icons.calendar_today)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: const InputDecoration(labelText: "Gender"),
                          items: ["Male", "Female", "Other"]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedGender = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _dobController,
                    decoration: const InputDecoration(
                        labelText: "Date of Birth (YYYY-MM-DD)",
                        prefixIcon: Icon(Icons.cake)),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1990),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now());
                      if (picked != null) {
                        _dobController.text =
                            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        final now = DateTime.now();
                        int age = now.year - picked.year;
                        if (now.month < picked.month ||
                            (now.month == picked.month &&
                                now.day < picked.day)) {
                          age--;
                        }
                        _ageController.text = age.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: "Weight (kg)"))),
                      const SizedBox(width: 15),
                      Expanded(
                          child: TextField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: "Height (cm)"))),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: "Access Level"),
                  items: const [
                    DropdownMenuItem(value: 'patient', child: Text("Patient")),
                    DropdownMenuItem(value: 'worker', child: Text("Health Worker")),
                    DropdownMenuItem(value: 'doctor', child: Text("Doctor")),
                  ],
                  onChanged: (val) => setState(() => _selectedRole = val!),
                ),
                if (_isRegistering && _selectedRole == 'doctor') ...[
                  const SizedBox(height: 20),
                  TextField(
                      controller: _degreeController,
                      decoration: const InputDecoration(
                          labelText: "Degree (e.g., MBBS)",
                          prefixIcon: Icon(Icons.school))),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _specController,
                      decoration: const InputDecoration(
                          labelText: "Specialization",
                          prefixIcon: Icon(Icons.local_hospital))),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _expController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Experience (Years)",
                          prefixIcon: Icon(Icons.work))),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: widget.isLoading
                        ? null
                        : () {
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
                              widget.onLogin(_userController.text,
                                  _passController.text, _selectedRole);
                            }
                          },
                    child: widget.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isRegistering ? "Register & Login" : "Access System",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () =>
                      setState(() => _isRegistering = !_isRegistering),
                  child: Text(_isRegistering
                      ? "Already have an account? Login"
                      : "Don't have an account? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}