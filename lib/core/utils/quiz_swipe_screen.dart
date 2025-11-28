import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/quiz_model.dart';

class QuizSwipeScreen extends ConsumerStatefulWidget {
  // 🎯 Removed 'category' from constructor as it is no longer used
  const QuizSwipeScreen({super.key});

  @override
  ConsumerState<QuizSwipeScreen> createState() => _QuizSwipeScreenState();
}

class _QuizSwipeScreenState extends ConsumerState<QuizSwipeScreen> {
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  int _score = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    // 🎯 LOGIC UPDATE: No Category Filter. Fetch EVERYTHING.
    // We fetch the full collection (400 docs is very small/cheap) to ensure true randomness.
    CollectionReference collection = FirebaseFirestore.instance.collection('quiz_bank');

    try {
      final snapshot = await collection.get();

      if (mounted) {
        final List<QuizQuestion> allLoaded = snapshot.docs
            .map((d) => QuizQuestion.fromFirestore(d))
            .toList();

        // 🎯 SHUFFLE: Randomize the entire deck
        allLoaded.shuffle();

        // 🎯 BATCH: Take the first 20 for this session
        final sessionQuestions = allLoaded.take(20).toList();

        setState(() {
          _questions = sessionQuestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading quiz: $e")));
      }
    }
  }

  void _handleSwipe(bool userGuessedFact) {
    final question = _questions[_currentIndex];
    final bool isCorrect = userGuessedFact == question.isFact;

    if (isCorrect) _score++;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildResultSheet(question, isCorrect),
    );
  }

  void _advanceToNext() {
    Navigator.pop(context); // Close bottom sheet
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _showFinalScore();
    }
  }

  void _showFinalScore() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Session Complete!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🏆", style: TextStyle(fontSize: 60)),
            const SizedBox(height: 10),
            Text("You scored $_score / ${_questions.length}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Great job! Come back later for a fresh mix.", textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Close screen
          }, child: const Text("Finish"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty) return const Scaffold(body: Center(child: Text("No questions found in the bank.")));

    final QuizQuestion? nextQuestion = (_currentIndex + 1 < _questions.length) ? _questions[_currentIndex + 1] : null;
    final QuizQuestion currentQuestion = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Daily Mix Trivia"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            color: Colors.indigo,
          ),
          const SizedBox(height: 20),

          const Text("Swipe Left for MYTH  •  Swipe Right for FACT",
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),

          const Spacer(),

          // THE CARD STACK
          SizedBox(
            height: 450,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Card (Next)
                if (nextQuestion != null)
                  Transform.scale(
                    scale: 0.95,
                    child: Transform.translate(
                      offset: const Offset(0, 20),
                      child: Opacity(
                        opacity: 0.6,
                        child: _buildQuizCard(nextQuestion),
                      ),
                    ),
                  ),

                // Foreground Card (Active)
                Dismissible(
                  key: Key(currentQuestion.id),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (direction) async {
                    bool guessedFact = direction == DismissDirection.startToEnd; // Swipe Right -> Fact
                    _handleSwipe(guessedFact);
                    return true; // Allow dismissal
                  },
                  background: _buildSwipeBackground(true), // Right Swipe (Fact)
                  secondaryBackground: _buildSwipeBackground(false), // Left Swipe (Myth)
                  child: _buildQuizCard(currentQuestion),
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildQuizCard(QuizQuestion q) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20)),
              child: Text(q.category.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade400, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 24),
            Text(
              q.question,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.4, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 40),

            // Instructional Arrows
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSwipeHint(Icons.arrow_back, "MYTH", Colors.red),
                _buildSwipeHint(Icons.arrow_forward, "FACT", Colors.green),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeHint(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.5), size: 28),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildSwipeBackground(bool isFact) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isFact ? Colors.green.shade400 : Colors.red.shade400,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: isFact ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        isFact ? "FACT" : "MYTH",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: 2),
      ),
    );
  }

  Widget _buildResultSheet(QuizQuestion q, bool isCorrect) {
    final Color color = isCorrect ? Colors.green : Colors.red;
    final String title = isCorrect ? "You got it!" : "Not quite...";
    final String answerText = q.isFact ? "It IS a Fact." : "Actually, it's a Myth.";

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: color, size: 50),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(answerText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
          const Divider(height: 30),
          const Align(alignment: Alignment.centerLeft, child: Text("Did you know?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(height: 5),
          Text(q.explanation, style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _advanceToNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Next Card"),
            ),
          )
        ],
      ),
    );
  }
}