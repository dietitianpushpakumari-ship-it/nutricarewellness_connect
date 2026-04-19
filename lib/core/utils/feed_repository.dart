import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_shift/core/utils/feed_item_model.dart';
// 🚀 IMPORT THE LIBRARY
import 'package:pure_shift/health_content.dart';

class FeedRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;

  bool get hasMore => _hasMoreData;

  Future<List<FeedItemModel>> fetchFeed(String tenantId, {String filter = 'All', bool isRefresh = false}) async {
    if (isRefresh) {
      _lastDocument = null;
      _hasMoreData = true;
    }

    // 1. Fetch from Firestore
    List<FeedItemModel> firestoreItems = [];
    if (_hasMoreData) {
      Query query = _firestore.collection('client_feed').where('tenantId', isEqualTo: tenantId);

      // ... (your existing filter logic) ...

      query = query.orderBy('createdAt', descending: true).limit(_pageSize);
      if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);

      try {
        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
          firestoreItems = snapshot.docs.map((doc) => FeedItemModel.fromFirestore(doc)).toList();
        } else {
          _hasMoreData = false;
        }
      } catch (e) {
        print("Feed Error: $e");
      }
    }

    // 🚀 2. THE INTEGRATION: If it's a refresh or first load, inject Library Tips
    if (isRefresh || _lastDocument == null) {
      // Pick 2-3 random tips from your masterHealthTips
      // lib/core/utils/feed_repository.dart

// Inside your fetchFeed method:
      final libraryTips = (List<HealthTip>.from(masterHealthTips)..shuffle())
          .take(3)
          .map((tip) => FeedItemModel(
        id: "lib_${tip.title['en']}",
        title: tip.title, // 🚀 Passing the Map to dynamic title
        description: tip.body['en']!,
        type: FeedContentType.socialPost, // 🚀 CRITICAL: Must be socialPost
        postedAt: DateTime.now(),
      ))
          .toList();

// Combine with Firestore items...

      // Combine them: Put one library tip at the top, others below
      if (firestoreItems.isNotEmpty) {
        firestoreItems.insert(0, libraryTips[0]);
        if (libraryTips.length > 1) firestoreItems.add(libraryTips[1]);
      } else {
        firestoreItems.addAll(libraryTips);
      }
    }

    return firestoreItems;
  }
}