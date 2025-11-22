import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String id;
  final String question;
  final bool isFact; // True = Fact, False = Myth
  final String explanation;
  final String category;
  final String? imageUrl;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.isFact,
    required this.explanation,
    required this.category,
    this.imageUrl,
  });

  factory QuizQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizQuestion(
      id: doc.id,
      question: data['question'] ?? '',
      isFact: data['isFact'] ?? false, // Key field
      explanation: data['explanation'] ?? 'No explanation provided.',
      category: data['category'] ?? 'General',
      imageUrl: data['imageUrl'],
    );
  }
}