import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';
import 'package:path_provider/path_provider.dart';

class FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _pageSize = 10;

  // Keep track of the last document for pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;

  bool get hasMore => _hasMoreData;

  // 🎯 1. FETCH INITIAL (Try Cache First, Then Network)
  Future<List<FeedItemModel>> fetchInitialFeed({String filter = 'All'}) async {
    _lastDocument = null;
    _hasMoreData = true;

    // A. Try loading from local cache first (Instant UI)
    List<FeedItemModel> cachedData = await _loadFromCache();
    if (cachedData.isNotEmpty) {
      // If we have cache, we can return it immediately.
      // Ideally, we should also trigger a background refresh,
      // but for "Less DB Hits", we can just return cache and let user pull-to-refresh.
      return cachedData;
    }

    // B. If cache empty, fetch from network
    return await fetchNextPage(filter: filter, isRefresh: true);
  }

  // 🎯 2. FETCH NEXT PAGE (Network Only)
  Future<List<FeedItemModel>> fetchNextPage({String filter = 'All', bool isRefresh = false}) async {
    if (!_hasMoreData && !isRefresh) return [];

    Query query = _firestore.collection('feed');

    // Apply Filters
    if (filter == 'Videos') query = query.where('type', isEqualTo: 'youtube');
    if (filter == 'Recipes') query = query.where('type', isEqualTo: 'article');
    if (filter == 'Offers') query = query.where('type', isEqualTo: 'promotion');

    // Ordering
    query = query.orderBy('isPinned', descending: true).orderBy('postedAt', descending: true);

    // Pagination
    if (_lastDocument != null && !isRefresh) {
      query = query.startAfterDocument(_lastDocument!);
    }

    query = query.limit(_pageSize);

    try {
      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        if (snapshot.docs.length < _pageSize) _hasMoreData = false;
      } else {
        _hasMoreData = false;
        return [];
      }

      final items = snapshot.docs.map((doc) => FeedItemModel.fromFirestore(doc)).toList();

      // 🎯 C. Save 1st page to cache if refreshing
      if (isRefresh) {
        await _saveToCache(items);
      }

      return items;
    } catch (e) {
      print("Feed Error: $e");
      return [];
    }
  }

  // --- CACHING LOGIC ---

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/feed_cache.json');
  }

  Future<void> _saveToCache(List<FeedItemModel> items) async {
    try {
      final file = await _localFile;
      // Convert list to JSON
      final String data = jsonEncode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      print("Cache Write Error: $e");
    }
  }

  Future<List<FeedItemModel>> _loadFromCache() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return [];

      final String content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => FeedItemModel.fromJson(e)).toList();
    } catch (e) {
      print("Cache Read Error: $e");
      return [];
    }
  }
}