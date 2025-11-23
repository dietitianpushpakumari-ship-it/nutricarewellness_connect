import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'package:path_provider/path_provider.dart';

class GeetaRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎯 MAIN FETCH METHOD
  Future<List<GeetaShloka>> getAllShlokas({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        print("✅ Loaded ${cached.length} Shlokas from Local Cache");
        return cached;
      }
    }

    return await _fetchFromNetwork();
  }

  // --- NETWORK ---
  Future<List<GeetaShloka>> _fetchFromNetwork() async {
    try {
      print("🌍 Fetching Shlokas from Firestore...");
      final snapshot = await _firestore.collection('geeta_library').get();

      final list = snapshot.docs
          .map((doc) => GeetaShloka.fromFirestore(doc))
          .toList();

      // Save to cache for next time
      await _saveToCache(list);
      return list;
    } catch (e) {
      print("Error fetching Geeta: $e");
      return [];
    }
  }

  // --- CACHING ---
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/geeta_cache.json');
  }

  Future<void> _saveToCache(List<GeetaShloka> items) async {
    try {
      final file = await _localFile;
      final String data = jsonEncode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      print("Cache Write Error: $e");
    }
  }

  Future<List<GeetaShloka>> _loadFromCache() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return [];

      final String content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => GeetaShloka.fromJson(e)).toList();
    } catch (e) {
      // If cache is corrupted, return empty so we fetch fresh
      return [];
    }
  }
}