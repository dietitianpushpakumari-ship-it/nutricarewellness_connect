import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/utils/feed_item_model.dart';

class FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;

  bool get hasMore => _hasMoreData;

  Future<List<FeedItemModel>> fetchFeed({String filter = 'All', bool isRefresh = false}) async {
    if (isRefresh) {
      _lastDocument = null;
      _hasMoreData = true;
    }

    if (!_hasMoreData) return [];

    Query query = _firestore.collection('client_feed');

    // 🎯 Apply Filters based on new Types
    if (filter == 'Videos') query = query.where('type', isEqualTo: 'video');
    if (filter == 'Recipes') query = query.where('type', isEqualTo: 'recipe');
    if (filter == 'Articles') query = query.where('type', isEqualTo: 'articleLink');

    // Order by Date
    query = query.orderBy('createdAt', descending: true);

    // Pagination
    if (_lastDocument != null) {
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

      return snapshot.docs.map((doc) => FeedItemModel.fromFirestore(doc)).toList();
    } catch (e) {
      print("Feed Fetch Error: $e");
      return [];
    }
  }
}