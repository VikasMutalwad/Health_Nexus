import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class Esp32Service {
  final StreamController<double> _ecgController =
      StreamController<double>.broadcast();

  Stream<double> get ecgStream => _ecgController.stream;

  bool isConnected = false;
  Timer? _pollingTimer;

  void connect() {
    if (isConnected) return;
    isConnected = true;
    _startPolling();
  }

  void disconnect() {
    isConnected = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void addSample(double value) {
    _ecgController.add(value);
  }

  void _startPolling() {
    // Connects to the existing project endpoint to feed the stream
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!isConnected) {
        timer.cancel();
        return;
      }
      try {
        final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/get-latest-vitals'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['ecg_graph'] != null) {
            final List<dynamic> rawEcg = data['ecg_graph'];
            for (var sample in rawEcg) {
              _ecgController.add((sample as num).toDouble());
            }
          }
        }
      } catch (e) {
        print("ESP32 Service Error: $e");
      }
    });
  }
}