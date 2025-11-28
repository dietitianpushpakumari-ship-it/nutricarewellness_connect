import 'package:cloud_firestore/cloud_firestore.dart';

// Match the Admin Enum exactly
enum FeedContentType {
  video,
  imagePost,
  articleLink,
  recipe,
  advertisement,
  socialPost,
}

class FeedItemModel {
  final String id;
  final String title;
  final String description;
  final FeedContentType type;

  final String? mediaUrl;      // Image URL or Youtube Thumbnail
  final String? actionUrl;     // External Link
  final String? callToAction;  // Button Label

  final Map<String, dynamic>? recipeData; // { ingredients, steps... }
  final List<String> targetTags;

  final DateTime postedAt;
  final int views;
  final int shares;

  FeedItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.mediaUrl,
    this.actionUrl,
    this.callToAction,
    this.recipeData,
    this.targetTags = const [],
    required this.postedAt,
    this.views = 0,
    this.shares = 0,
  });

  factory FeedItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedItemModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      // Robust Enum Parsing
      type: FeedContentType.values.firstWhere(
              (e) => e.name == (data['type'] ?? 'imagePost'),
          orElse: () => FeedContentType.imagePost),
      mediaUrl: data['mediaUrl'],
      actionUrl: data['actionUrl'],
      callToAction: data['callToAction'],
      recipeData: data['recipeData'],
      targetTags: List<String>.from(data['targetTags'] ?? []),
      postedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      views: data['views'] ?? 0,
      shares: data['shares'] ?? 0,
    );
  }
}