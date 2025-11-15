import 'package:flutter/services.dart';

class FlutterNativeTimezone {
  static const _channel = MethodChannel('flutter_native_timezone');

  static Future<String> getLocalTimezone() async {
    return await _channel.invokeMethod('getLocalTimezone');
  }
}
