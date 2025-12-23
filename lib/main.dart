import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart'; // Ab ye yahan se load hoga

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase Initialized Successfully");
  } catch (e) {
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
      // Yahan se hum seedha AuthWrapper bula rahe hain
      // AuthWrapper decide karega ki Login dikhana hai ya Dashboard
      home: const AuthWrapper(),
    );
  }
}