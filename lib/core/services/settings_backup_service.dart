import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsBackupService {
  /// Exports all SharedPreferences keys into a JSON string.
  static Future<String> exportToJson() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, dynamic> settingsMap = {};

    for (String key in keys) {
      final value = prefs.get(key);
      if (value != null) {
        settingsMap[key] = value;
      }
    }

    return jsonEncode(settingsMap);
  }

  /// Imports settings from a JSON string into SharedPreferences.
  static Future<void> importFromJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> settingsMap = jsonDecode(jsonStr);

    for (var entry in settingsMap.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.cast<String>());
      }
    }
  }
}

