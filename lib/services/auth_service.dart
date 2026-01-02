import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_session.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Current User Stream (For AuthWrapper to listen)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 2. Fetch User Session (Profile Data)
  Future<UserSession?> getUserSession(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return UserSession(
        userId: uid,
        username: _auth.currentUser?.email ?? '',
        role: data['role'] ?? 'patient',
        name: data['name'] ?? '',
        age: int.tryParse(data['age'].toString()) ?? 0,
        gender: data['gender'] ?? 'Male',
        dob: data['dob'] ?? '',
        weight: double.tryParse(data['weight'].toString()) ?? 70.0,
        height: double.tryParse(data['height'].toString()) ?? 175.0,
      );
    } catch (e) {
      throw Exception("Error fetching user session: $e");
    }
  }

  // 3. Login
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 4. Register
  Future<User?> register({
    required String email,
    required String password,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      // Create Auth User
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Save Profile to Firestore
        await _db.collection('users').doc(credential.user!.uid).set(userProfile);
        return credential.user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Registration failed");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 5. Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 6. Forgot Password
  Future<void> resetPassword(String email) async {
    if (email.isEmpty) throw Exception("Email required");
    await _auth.sendPasswordResetEmail(email: email);
  }
}