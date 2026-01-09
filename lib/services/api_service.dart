import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Use the live URL for release builds and localhost for debug builds.
  final String baseUrl = kReleaseMode
      ? 'https://health-nexus-3a2x.onrender.com' // <-- IMPORTANT: Replace with your actual Render URL
      : Platform.isAndroid
          ? 'http://10.0.2.2:3000'
          : 'http://localhost:3000';

  // Helper to get the current user's ID token
  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  // POST: Save User Profile
  Future<void> saveUserProfile(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('User not logged in');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/user-profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save profile: ${response.body}');
    }
  }

  // POST: Save Health Data (Heart rate, BP, etc.)
  Future<void> saveHealthData(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/api/health-data'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save health data: ${response.body}');
    }
  }

  // GET: Fetch User Profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await _getToken();
    if (token == null) throw Exception('User not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/api/user-profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 404) return {}; // Profile not found
    throw Exception('Failed to load profile: ${response.body}');
  }

  // GET: Fetch Secure Health Data
  Future<String> getHealthData() async {
    final token = await _getToken();
    if (token == null) throw Exception('User not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/api/health-data'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) return response.body;
    throw Exception('Failed to load health data');
  }
}