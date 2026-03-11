import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_session.dart';
import 'auth_screen.dart';
import '../patient/patient_dashboard.dart';
import '../doctor/doctor_dashboard.dart'; 
import '../worker/worker_dashboard.dart'; 

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
      return AuthScreen(
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