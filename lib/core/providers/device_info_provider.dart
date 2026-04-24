import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';

/// 📱 Data model for the current device information.
class DeviceDisplayInfo {
  final String deviceName;
  final IconData platformIcon;
  final String model;
  final bool isAndroid;

  DeviceDisplayInfo({
    required this.deviceName,
    required this.platformIcon,
    required this.model,
    required this.isAndroid,
  });
}

/// 🎯 FutureProvider to fetch and format current device information.
final currentDeviceInfoProvider = FutureProvider<DeviceDisplayInfo>((ref) async {
  final plugin = DeviceInfoPlugin();
  
  try {
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      // Format: "Manufacturer Model" (e.g., Samsung SM-S928B)
      final manufacturer = _capitalize(info.manufacturer);
      final model = info.model;
      
      return DeviceDisplayInfo(
        deviceName: "$manufacturer $model",
        platformIcon: Icons.phone_android,
        model: model,
        isAndroid: true,
      );
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      // In iOS, .name is the user-defined name or friendly name.
      return DeviceDisplayInfo(
        deviceName: info.name,
        platformIcon: Icons.phone_iphone,
        model: info.model,
        isAndroid: false,
      );
    }
  } catch (e) {
    appLogger.warning('Error fetching device info', context: 'DeviceInfoProvider', error: e);
  }

  // Fallback
  return DeviceDisplayInfo(
    deviceName: Platform.isAndroid ? "Perangkat Android" : "Perangkat iOS",
    platformIcon: Platform.isAndroid ? Icons.phone_android : Icons.phone_iphone,
    model: "Unknown",
    isAndroid: Platform.isAndroid,
  );
});

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
