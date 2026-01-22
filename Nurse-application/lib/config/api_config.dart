import 'package:flutter/foundation.dart';

class ApiConfig {
  // -------------------------------------------------------------
  // CONFIGURATION
  // -------------------------------------------------------------

  // 1. LOCAL DEVELOPMENT (YOUR PC + PHONE ON WIFI)
  static const String _localIp = '192.168.0.7'; // Your PC's IP
  static const String _localUrl = 'http://$_localIp:3000';

  // 2. ANDROID EMULATOR (SPECIAL GOOGLE IP)
  // static const String _emulatorUrl = 'http://10.0.2.2:3000';

  // 3. PRODUCTION DEPLOYMENT (YOUR CLOUD SERVER)
  // When you deploy, change this to your real domain (e.g., https://api.zaqencare.com)
  static const String _productionUrl = 'https://your-production-backend.com';

  // -------------------------------------------------------------
  // CURRENT ACTIVE URL
  // -------------------------------------------------------------

  // LOGIC:
  // - If Release Mode (Deployment) -> Use Production URL
  // - If Debug Mode (Testing) -> Detects if you want Emulator or Local IP
  static String get baseUrl {
    if (kReleaseMode) {
      // 🚀 PRODUCTION MODE
      // Ensure you have set _productionUrl above correctly before publishing!
      return _productionUrl;
    } else {
      // 🛠️ DEBUG / DEVELOPMENT MODE
      // You can manually toggle this, or we can assume physical device mostly
      // Return _emulatorUrl if you are strictly using Emulator.
      return _localUrl;
    }
  }

  // Endpoints
  static String get geocodeUrl => '$baseUrl/api/geocode';
  static String get directionsUrl => '$baseUrl/api/directions';
}
