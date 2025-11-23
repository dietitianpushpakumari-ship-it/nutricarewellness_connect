import 'package:cloud_firestore/cloud_firestore.dart';

class GeetaShloka {
  final String id;
  final int chapter;
  final int verse;
  final String sanskrit;
  final String hindiMeaning;
  final String oriyaMeaning;
  final String englishMeaning;
  final List<String> tags;

  GeetaShloka({
    required this.id,
    required this.chapter,
    required this.verse,
    required this.sanskrit,
    required this.hindiMeaning,
    required this.oriyaMeaning,
    required this.englishMeaning,
    required this.tags,
  });

  // FROM FIREBASE
  factory GeetaShloka.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GeetaShloka(
      id: doc.id,
      chapter: data['chapter'] ?? 0,
      verse: data['verse'] ?? 0,
      sanskrit: data['sanskrit'] ?? '',
      hindiMeaning: data['hindiMeaning'] ?? '',
      oriyaMeaning: data['oriyaMeaning'] ?? '',
      englishMeaning: data['englishMeaning'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // 🎯 NEW: FROM LOCAL CACHE (JSON)
  factory GeetaShloka.fromJson(Map<String, dynamic> json) {
    return GeetaShloka(
      id: json['id'] ?? '',
      chapter: json['chapter'] ?? 0,
      verse: json['verse'] ?? 0,
      sanskrit: json['sanskrit'] ?? '',
      hindiMeaning: json['hindiMeaning'] ?? '',
      oriyaMeaning: json['oriyaMeaning'] ?? '',
      englishMeaning: json['englishMeaning'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  // 🎯 NEW: TO LOCAL CACHE (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Store ID explicitly for cache
      'chapter': chapter,
      'verse': verse,
      'sanskrit': sanskrit,
      'hindiMeaning': hindiMeaning,
      'oriyaMeaning': oriyaMeaning,
      'englishMeaning': englishMeaning,
      'tags': tags,
    };
  }

  // TO FIREBASE (If needed for uploading)
  Map<String, dynamic> toMap() {
    return {
      'chapter': chapter,
      'verse': verse,
      'sanskrit': sanskrit,
      'hindiMeaning': hindiMeaning,
      'oriyaMeaning': oriyaMeaning,
      'englishMeaning': englishMeaning,
      'tags': tags,
    };
  }
}