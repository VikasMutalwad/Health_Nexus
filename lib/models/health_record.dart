// Location: lib/models/health_record.dart

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