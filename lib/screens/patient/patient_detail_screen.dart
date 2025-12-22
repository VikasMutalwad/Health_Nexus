import 'package:flutter/material.dart';

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