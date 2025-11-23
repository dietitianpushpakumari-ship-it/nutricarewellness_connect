import 'package:cloud_firestore/cloud_firestore.dart';

class SpiritualMantraModel {
  final String id;
  final String name;
  final String meaning;
  final String youtubeUrl;
  final String? audioUrl; // For background play if needed later
  final String? sanskritText;

  SpiritualMantraModel({
    required this.id,
    required this.name,
    required this.meaning,
    required this.youtubeUrl,
    this.audioUrl,
    this.sanskritText,
  });

  factory SpiritualMantraModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpiritualMantraModel(
      id: doc.id,
      name: data['name'] ?? '',
      meaning: data['meaning'] ?? '',
      youtubeUrl: data['youtubeUrl'] ?? '',
      audioUrl: data['audioUrl'],
      sanskritText: data['sanskritText'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'meaning': meaning,
      'youtubeUrl': youtubeUrl,
      'audioUrl': audioUrl,
      'sanskritText': sanskritText,
    };
  }
}