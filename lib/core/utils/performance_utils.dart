import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class PerformanceManager {
  static bool isLowEndDevice = false;

  static Future<void> checkDevicePower() async {
    if (kIsWeb) {
      // It's running in a browser, skip any dart:io checks
      print("Running on Web, skipping device power check.");
      return;
    }
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      // 🚀 REDMI NOTE 8 CHECK: API < 30 or RAM < 4GB usually means lag
      // You can also check specific models if needed
      if (androidInfo.version.sdkInt < 30) {
        isLowEndDevice = true;
      }
    }
  }
}