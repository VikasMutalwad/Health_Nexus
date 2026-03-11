import 'package:flutter/material.dart';

Widget buildResultRow(
  String label,
  String value,
  Color color, {
  IconData? icon,
  Color? iconColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor ?? color),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class DiagnosticReportWidget extends StatelessWidget {
  final String patientName;
  final String patientAge;
  final String patientSex;
  final String patientMobile;
  final DateTime timestamp;
  final Map<String, dynamic> vitalsData;
  final Map<String, dynamic> urineData;
  final String diagnosis;
  final String severity;
  final bool isEcgPerformed;
  final bool isUrineSkipped;

  const DiagnosticReportWidget({
    super.key,
    required this.patientName,
    required this.patientAge,
    required this.patientSex,
    required this.patientMobile,
    required this.timestamp,
    required this.vitalsData,
    required this.urineData,
    required this.diagnosis,
    required this.severity,
    required this.isEcgPerformed,
    required this.isUrineSkipped,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.green;
    if (severity == 'High') {
      statusColor = Colors.red;
    } else if (severity == 'Moderate') statusColor = Colors.orange;

    final ecgValues = (vitalsData['ecg_graph'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    String getVital(String key) {
      return vitalsData[key]?.toString() ?? '--';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: statusColor),
                  const SizedBox(width: 10),
                  const Text("AI Clinical Interpretation",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Text(diagnosis),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text("Vital Signs",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        buildResultRow(
          "Heart Rate",
          getVital("Heart Rate"),
          Colors.black,
          icon: Icons.favorite,
          iconColor: Colors.red,
        ),
        buildResultRow(
          "SpO2",
          getVital("SpO2"),
          Colors.black,
          icon: Icons.water_drop,
          iconColor: Colors.blue,
        ),
        buildResultRow(
          "Body Temperature",
          getVital("Body Temperature"),
          Colors.black,
          icon: Icons.thermostat,
          iconColor: Colors.orange,
        ),
        buildResultRow(
          "ECG Status",
          isEcgPerformed ? "Completed" : "Not Performed",
          Colors.black,
          icon: Icons.monitor_heart,
          iconColor: Colors.green,
        ),
        if (isEcgPerformed && ecgValues.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            height: 100,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.show_chart, color: Colors.red, size: 40),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text("Urine Analysis",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (isUrineSkipped)
          const Text("Urine test was skipped.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
        else
          ...urineData.entries.map((e) {
            String label =
                e.key.replaceAll('urine_', '').replaceAll('_', ' ').toUpperCase();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(e.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
      ],
    );
  }


}
