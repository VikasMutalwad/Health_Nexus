import 'package:cloud_firestore/cloud_firestore.dart';

class PatientReport {
  final String id;
  final String patientName;
  final Map<String, dynamic> results;
  final DateTime timestamp;
  final String status;

  PatientReport({
    required this.id,
    required this.patientName,
    required this.results,
    required this.timestamp,
    required this.status,
  });

  factory PatientReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return PatientReport(
      id: doc.id,
      patientName: data?['patientName']?.toString() ?? 'Unknown Patient',
      results: data?['results'] is Map
          ? Map<String, dynamic>.from(data!['results'] as Map)
          : {},
      timestamp: parseDate(data?['timestamp']),
      status: data?['status']?.toString() ?? 'unknown',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientName': patientName,
      'results': results,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  factory PatientReport.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return PatientReport(
      id: id,
      patientName: data['patientName']?.toString() ?? 'Unknown Patient',
      results: data['results'] is Map
          ? Map<String, dynamic>.from(data['results'] as Map)
          : {},
      timestamp: parseDate(data['timestamp']),
      status: data['status']?.toString() ?? 'unknown',
    );
  }

  PatientReport copyWith({
    String? id,
    String? patientName,
    Map<String, dynamic>? results,
    DateTime? timestamp,
    String? status,
  }) {
    return PatientReport(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      results: results ?? this.results,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }
}