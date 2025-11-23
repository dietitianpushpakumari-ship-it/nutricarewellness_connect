import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedType { youtube, image, article, promotion, facebookPost }

class FeedItemModel {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? actionUrl;
  final FeedType type;
  final DateTime postedAt;
  final bool isPinned;

  FeedItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.actionUrl,
    required this.type,
    required this.postedAt,
    this.isPinned = false,
  });

  // ... (Keep your existing fromFirestore factory) ...
  factory FeedItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedItemModel(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
      type: FeedType.values.firstWhere((e) => e.name == (data['type'] ?? 'article'), orElse: () => FeedType.article),
      postedAt: (data['postedAt'] as Timestamp).toDate(),
      isPinned: data['isPinned'] ?? false,
    );
  }

  // 🎯 NEW: For Local Caching (File IO)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'type': type.name,
      'postedAt': postedAt.toIso8601String(), // Store date as String
      'isPinned': isPinned,
    };
  }

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    return FeedItemModel(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      imageUrl: json['imageUrl'],
      actionUrl: json['actionUrl'],
      type: FeedType.values.firstWhere((e) => e.name == json['type'], orElse: () => FeedType.article),
      postedAt: DateTime.parse(json['postedAt']),
      isPinned: json['isPinned'] ?? false,
    );
  }
}