import 'package:flutter/material.dart';

class GlobalKeys {
  GlobalKeys._(); // Private constructor

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // 🚀 CRITICAL: Must be ScaffoldMessengerState
  static final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();
}