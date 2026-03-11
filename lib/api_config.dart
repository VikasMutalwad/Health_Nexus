class ApiConfig {
  static const bool isEmulator = false; // Set to false if running on a real device

  static String baseUrl = isEmulator
      ? "http://10.0.2.2:5000"   // Emulator
      : "http://192.168.10.183:5000"; // Real device (same WiFi as laptop)
}