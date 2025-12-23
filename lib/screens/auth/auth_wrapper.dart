import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_session.dart';
import '../../services/auth_service.dart'; // Import Service
import 'login_screen.dart';
import '../patient/patient_dashboard.dart';
import '../doctor/doctor_dashboard.dart'; 
import '../worker/worker_dashboard.dart'; 

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService(); // Instance of Service
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
    // Service se stream suno
    _authSubscription = _authService.authStateChanges.listen((User? user) async {
      if (user != null && mounted) {
        await _setSessionFromUser(user.uid);
      } else {
        if (mounted) setState(() => _session = null);
      }
    });
  }

  Future<void> _setSessionFromUser(String uid) async {
    try {
      // Service se data mango
      final session = await _authService.getUserSession(uid);
      if (mounted) {
        setState(() {
          _session = session;
        });
      }
    } catch (e) {
      debugPrint("Session Error: $e");
    }
  }

  void _login(String email, String password, String role) async {
    setState(() => _isLoggingIn = true);
    try {
      await _authService.login(email, password); // Service Call
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception:', '')}")));
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _register(Map<String, dynamic> data) async {
    setState(() => _isLoggingIn = true);
    try {
      final userProfile = Map<String, dynamic>.from(data);
      userProfile.remove('password'); 
      userProfile['createdAt'] = DateTime.now().toIso8601String();

      // Service Call
      final user = await _authService.register(
        email: data['username'],
        password: data['password'],
        userProfile: userProfile
      );
      
      if (user != null && mounted) await _setSessionFromUser(user.uid);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception:', '')}")));
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _logout() async {
    await _authService.logout(); // Service Call
  }

  void _forgotPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset email sent!")));
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginScreen(
          onLogin: _login,
          onRegister: _register,
          onForgotPassword: _forgotPassword, 
          isLoading: _isLoggingIn);
    }
    
    if (_session!.role == 'patient') {
      return PatientDashboard(session: _session!, onLogout: _logout);
    } else if (_session!.role == 'doctor') {
      return DoctorDashboard(session: _session!, onLogout: _logout);
    } else {
      return HealthWorkerDashboard(session: _session!, onLogout: _logout);
    }
  }
}