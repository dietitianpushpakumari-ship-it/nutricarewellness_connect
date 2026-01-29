import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/localization/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  /// Helper to get translated string
  /// Usage: context.tr('key_name')
  String tr(String key) {
    return AppLocalizations.of(this)?.translate(key) ?? key;
  }
}