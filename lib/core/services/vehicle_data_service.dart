import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

enum VehicleCategory { motor, mobil }

class VehicleModel {
  final String merk;
  final String tipe;

  VehicleModel({required this.merk, required this.tipe});

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(merk: json['merk'] ?? '', tipe: json['tipe'] ?? '');
  }

  String get displayName => '$merk $tipe'.trim();
}

class VehicleDataService {
  static final Map<VehicleCategory, List<VehicleModel>> _cache = {};

  static String _getAssetPath(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.motor:
        return 'assets/data/master_motor.json';
      case VehicleCategory.mobil:
        return 'assets/data/master_mobil.json';
    }
  }

  static Future<void> _loadAsset(VehicleCategory category) async {
    if (_cache.containsKey(category)) return;

    final path = _getAssetPath(category);
    try {
      dev.log('VehicleDataService: Loading asset for $category from $path');
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = json.decode(jsonString);

      _cache[category] = jsonList.map((e) => VehicleModel.fromJson(e)).toList();
      dev.log(
        'VehicleDataService: Successfully loaded ${_cache[category]!.length} items for $category',
      );
    } catch (e, stack) {
      dev.log(
        'VehicleDataService: Error loading asset for $category',
        error: e,
        stackTrace: stack,
      );
      _cache[category] = []; // Avoid retrying broken assets
    }
  }

  static Future<List<String>> getSuggestions(
    String query,
    VehicleCategory category,
  ) async {
    if (query.isEmpty) return [];

    // Lazy load if not in cache
    if (!_cache.containsKey(category)) {
      await _loadAsset(category);
    }

    final data = _cache[category] ?? [];
    final normalizedQuery = query.toLowerCase();

    // Suggest both merk + tipe
    final suggestions = <String>{};

    for (var item in data) {
      final fullMatch = item.displayName;
      if (fullMatch.toLowerCase().contains(normalizedQuery)) {
        suggestions.add(fullMatch);
      }
      if (suggestions.length >= 15) break;
    }

    return suggestions.toList();
  }
}

