import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<Map<String, dynamic>> analyzeReport({
    required String patientId,
    required Map<String, dynamic> vitalsData,
    required List<File> urineImages,
  }) async {
    var uri = Uri.parse("$baseUrl/analyze-report");
    var request = http.MultipartRequest('POST', uri);

    request.fields['patient_id'] = patientId;
    request.fields['vitals_data'] = jsonEncode(vitalsData);

    for (var img in urineImages) {
      request.files.add(await http.MultipartFile.fromPath('urine_images', img.path));
    }

    var response = await request.send().timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      return jsonDecode(responseData);
    } else {
      throw Exception("Backend returned ${response.statusCode}");
    }
  }
}