import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_shift/layout_utils.dart'; // 🎯 NEW IMPORT

// =============================================================================
// 1. MODELS
// =============================================================================
enum QuestionType { singleChoice, slider, yesNo }
enum LifestyleCategory { biometrics, diabetes, hormonal, heart, gut, toxicity, sleep, immunity }

class ScreeningQuestion {
  final String id;
  final String text;
  final QuestionType type;
  final LifestyleCategory category;
  final List<String>? options;
  final double? min;
  final double? max;
  final String? unit;
  final bool isRedFlag;

  ScreeningQuestion({
    required this.id, required this.text, required this.type, required this.category,
    this.options, this.min, this.max, this.unit, this.isRedFlag = false,
  });
}

class HealthPath {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<ScreeningQuestion> specificQuestions;

  HealthPath({required this.id, required this.title, required this.description, required this.icon, required this.specificQuestions});
}

class HealthInsight {
  final String title;
  final String indicator;
  final String focusArea;
  final bool isCritical;

  HealthInsight({required this.title, required this.indicator, required this.focusArea, this.isCritical = false});
}

// =============================================================================
// 2. ASSESSMENT & INSIGHT ENGINES
// =============================================================================
class InsightEngine {
  static List<HealthInsight> analyze(Map<String, dynamic> answers) {
    List<HealthInsight> insights = [];

    if (answers['eyebrows'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Thyroid Function Indicator",
        indicator: "Outer eyebrow thinning is commonly associated with sluggish thyroid function (Hertoghe’s Sign).",
        focusArea: "Possible area to look at: Full Thyroid Panel (TSH, T3, T4, Anti-TPO) and assessing cellular metabolism.",
      ));
    }
    if (answers['cold_intolerance'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Metabolic Rate Possibility",
        indicator: "Chronically cold hands/feet can indicate that your basal metabolic fire is running low.",
        focusArea: "Possible area to look at: Iron/Ferritin levels and overall caloric/protein absorption.",
      ));
    }
    if (answers['xanthelasma'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Lipid Profile Indicator",
        indicator: "Yellowish bumps on eyelids are often visible cholesterol deposits.",
        focusArea: "Possible area to look at: Advanced Lipid Profile and evaluating liver congestion.",
        isCritical: true,
      ));
    }
    if (answers['stool_float'] == 'Yes' || answers['fat_nausea'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Fat Malabsorption Risk",
        indicator: "Floating stools or nausea after fatty meals suggests the gallbladder may not be releasing enough bile.",
        focusArea: "Possible area to look at: Gallbladder function, liver health, and digestive enzyme production.",
      ));
    }
    if (answers['morning_headache'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Vascular Pressure Risk",
        indicator: "Heavy morning headaches can sometimes signal overnight blood pressure spikes or Sleep Apnea.",
        focusArea: "Possible area to look at: Morning blood pressure monitoring and sleep quality tracking.",
        isCritical: true,
      ));
    }
    if (answers['polyuria'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Blood Glucose Indicator",
        indicator: "Frequent nighttime urination can be the body's attempt to flush excess circulating sugar.",
        focusArea: "Possible area to look at: Fasting Glucose and HbA1c levels to rule out pre-diabetes.",
        isCritical: true,
      ));
    }
    if (answers['acanthosis'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Insulin Resistance Possibility",
        indicator: "Dark, velvety skin patches on the neck or armpits strongly correlate with chronically elevated insulin.",
        focusArea: "Possible area to look at: Fasting Insulin levels, HOMA-IR score, and carbohydrate tolerance.",
        isCritical: true,
      ));
    }
    if (answers['acid_reflux'] == 'Yes') {
      insights.add(HealthInsight(
        title: "Stomach Acid Imbalance",
        indicator: "Chronic reliance on antacids often masks low stomach acid rather than high acid, impairing nutrient breakdown.",
        focusArea: "Possible area to look at: Gut microbiome health and restoring natural gastric pH.",
      ));
    }

    return insights;
  }
}

class AssessmentEngine {
  static final List<ScreeningQuestion> _coreQuestions = [
    ScreeningQuestion(id: 'height', text: "Height?", type: QuestionType.slider, category: LifestyleCategory.biometrics, min: 120, max: 220, unit: "cm"),
    ScreeningQuestion(id: 'weight', text: "Weight?", type: QuestionType.slider, category: LifestyleCategory.biometrics, min: 30, max: 180, unit: "kg"),
    ScreeningQuestion(id: 'waist_hip', text: "Is your waist larger than your hips?", type: QuestionType.yesNo, category: LifestyleCategory.biometrics, isRedFlag: true),
    ScreeningQuestion(id: 'bp_dizzy', text: "Do you get dizzy when standing up quickly?", type: QuestionType.yesNo, category: LifestyleCategory.heart, isRedFlag: true),
    ScreeningQuestion(id: 'water', text: "Daily water intake?", type: QuestionType.singleChoice, category: LifestyleCategory.toxicity, options: ["< 1.5 L", "1.5 - 2.5 L", "3 L+"]),
    ScreeningQuestion(id: 'cooking_oil', text: "Primary cooking oil?", type: QuestionType.singleChoice, category: LifestyleCategory.toxicity, options: ["Ghee/Coconut/Olive", "Refined (Sunflower/Soy)", "Mustard"]),
    ScreeningQuestion(id: 'sleep_hrs', text: "Avg Sleep?", type: QuestionType.slider, category: LifestyleCategory.sleep, min: 3, max: 12, unit: "hrs"),
  ];

  static final List<HealthPath> paths = [
    HealthPath(
      id: 'metabolic', title: 'Weight & Blood Sugar', description: 'Insulin resistance, cravings & fat loss barriers.', icon: Icons.monitor_weight_outlined,
      specificQuestions: [
        ScreeningQuestion(id: 'polyuria', text: "Do you wake up to urinate >1 time/night?", type: QuestionType.yesNo, category: LifestyleCategory.diabetes, isRedFlag: true),
        ScreeningQuestion(id: 'crash', text: "Do you feel sleepy/foggy 30 mins after lunch?", type: QuestionType.yesNo, category: LifestyleCategory.diabetes),
        ScreeningQuestion(id: 'hangry', text: "Do you get irritable/shaky if you miss a meal?", type: QuestionType.yesNo, category: LifestyleCategory.diabetes),
        ScreeningQuestion(id: 'acanthosis', text: "Dark patches on neck/armpits?", type: QuestionType.yesNo, category: LifestyleCategory.diabetes, isRedFlag: true),
        ScreeningQuestion(id: 'xanthelasma', text: "Yellowish bumps on eyelids?", type: QuestionType.yesNo, category: LifestyleCategory.heart, isRedFlag: true),
        ScreeningQuestion(id: 'fat_nausea', text: "Do you feel nauseous after fatty/fried meals?", type: QuestionType.yesNo, category: LifestyleCategory.gut),
        ScreeningQuestion(id: 'eating_speed', text: "Do you eat fast (<15 mins)?", type: QuestionType.yesNo, category: LifestyleCategory.gut),
        ScreeningQuestion(id: 'sugar_crave', text: "Do you 'need' sweets after meals?", type: QuestionType.yesNo, category: LifestyleCategory.diabetes),
      ],
    ),
    HealthPath(
      id: 'hormonal', title: 'PCOS & Thyroid', description: 'Periods, hair fall, acne & fatigue.', icon: Icons.spa_outlined,
      specificQuestions: [
        ScreeningQuestion(id: 'cycle_regularity', text: "Are periods irregular?", type: QuestionType.yesNo, category: LifestyleCategory.hormonal),
        ScreeningQuestion(id: 'jawline_acne', text: "Cystic acne on jawline/chin?", type: QuestionType.yesNo, category: LifestyleCategory.hormonal, isRedFlag: true),
        ScreeningQuestion(id: 'hirsutism', text: "Coarse hair on chin/chest?", type: QuestionType.yesNo, category: LifestyleCategory.hormonal, isRedFlag: true),
        ScreeningQuestion(id: 'cold_intolerance', text: "Are hands/feet constantly cold?", type: QuestionType.yesNo, category: LifestyleCategory.hormonal),
        ScreeningQuestion(id: 'eyebrows', text: "Thinning of outer eyebrows?", type: QuestionType.yesNo, category: LifestyleCategory.hormonal),
        ScreeningQuestion(id: 'constipation', text: "Chronic constipation?", type: QuestionType.yesNo, category: LifestyleCategory.gut),
        ScreeningQuestion(id: 'tired_wired', text: "Tired all day but awake at night?", type: QuestionType.yesNo, category: LifestyleCategory.sleep, isRedFlag: true),
      ],
    ),
    HealthPath(
      id: 'cardio', title: 'Heart & Hypertension', description: 'BP, palpitations & cholesterol check.', icon: Icons.favorite_border,
      specificQuestions: [
        ScreeningQuestion(id: 'morning_headache', text: "Wake up with heavy head/neck pain?", type: QuestionType.yesNo, category: LifestyleCategory.heart, isRedFlag: true),
        ScreeningQuestion(id: 'tinnitus', text: "Ringing in ears (Tinnitus)?", type: QuestionType.yesNo, category: LifestyleCategory.heart),
        ScreeningQuestion(id: 'breath_stairs', text: "Short of breath after 1 flight of stairs?", type: QuestionType.yesNo, category: LifestyleCategory.heart, isRedFlag: true),
        ScreeningQuestion(id: 'salt_swell', text: "Do fingers swell after salty food?", type: QuestionType.yesNo, category: LifestyleCategory.heart),
        ScreeningQuestion(id: 'family_heart', text: "Family history of heart attack <55 yrs?", type: QuestionType.yesNo, category: LifestyleCategory.heart),
      ],
    ),
    HealthPath(
      id: 'gut_immune', title: 'Gut & Immunity', description: 'Bloating, acidity & recovery speed.', icon: Icons.shield_outlined,
      specificQuestions: [
        ScreeningQuestion(id: 'bloating_time', text: "Get more bloated as day goes on?", type: QuestionType.yesNo, category: LifestyleCategory.gut),
        ScreeningQuestion(id: 'acid_reflux', text: "Rely on antacids (Eno/Pantop)?", type: QuestionType.yesNo, category: LifestyleCategory.gut, isRedFlag: true),
        ScreeningQuestion(id: 'tongue_coat', text: "White coating on tongue?", type: QuestionType.yesNo, category: LifestyleCategory.gut),
        ScreeningQuestion(id: 'stool_float', text: "Do stools float/look greasy?", type: QuestionType.yesNo, category: LifestyleCategory.gut),
        ScreeningQuestion(id: 'antibiotics', text: "Antibiotics >2 times last year?", type: QuestionType.yesNo, category: LifestyleCategory.immunity),
        ScreeningQuestion(id: 'recovery_slow', text: "Does flu take >7 days to clear?", type: QuestionType.yesNo, category: LifestyleCategory.immunity, isRedFlag: true),
      ],
    ),
    HealthPath(
      id: 'weight_mgmt', title: 'Weight Management', description: 'Fat loss, muscle gain & metabolism speed.', icon: Icons.fitness_center_rounded,
      specificQuestions: [
        ScreeningQuestion(id: 'weight_goal', text: "What is your primary goal?", type: QuestionType.singleChoice, category: LifestyleCategory.biometrics, options: ["Lose Fat", "Gain Muscle", "Tone Body"]),
        ScreeningQuestion(id: 'diet_history', text: "Have you tried 'crash diets' before?", type: QuestionType.yesNo, category: LifestyleCategory.toxicity),
        ScreeningQuestion(id: 'activity_level', text: "Weekly workout frequency?", type: QuestionType.singleChoice, category: LifestyleCategory.biometrics, options: ["Sedentary", "1-2 days", "3-5 days", "Athlete"]),
        ScreeningQuestion(id: 'energy_levels', text: "Do you feel low energy by 4 PM?", type: QuestionType.yesNo, category: LifestyleCategory.hormonal),
        ScreeningQuestion(id: 'hunger_type', text: "When is your hunger highest?", type: QuestionType.singleChoice, category: LifestyleCategory.gut, options: ["Late Night", "Post-Workout", "Always hungry"]),
        ScreeningQuestion(id: 'protein_intake', text: "Do you track your protein?", type: QuestionType.yesNo, category: LifestyleCategory.biometrics),
      ],
    ),
  ];

  static List<ScreeningQuestion> getFullQuestionSet(HealthPath path) => [...path.specificQuestions, ..._coreQuestions];

  static List<HealthPath> getAvailablePaths(double age, String gender, [String? selectedTrack]) {
    return paths.where((path) {
      if (gender == 'Male' && path.id == 'hormonal') return false;
      if (selectedTrack != null) {
        if (selectedTrack == 'WEIGHT_MGMT') return path.id == 'weight_mgmt';
        if (selectedTrack == 'CLINICAL_REVERSAL') return path.id != 'weight_mgmt';
      }
      return true;
    }).toList();
  }
}

// =============================================================================
// 3. UI
// =============================================================================
class ClinicalAssessmentFlow extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientGender;
  final double clientAge;

  const ClinicalAssessmentFlow({
    super.key, required this.clientId, required this.clientName,
    this.clientGender = "Female", this.clientAge = 35.0,
  });

  @override
  State<ClinicalAssessmentFlow> createState() => _ClinicalAssessmentFlowState();
}

class _ClinicalAssessmentFlowState extends State<ClinicalAssessmentFlow> {
  final Color clinicalSage = const Color(0xFF10B981);
  final PageController _pageController = PageController();
  bool _isForSelf = true;
  // Dynamic Profile Variables
  bool _isProfileSetupComplete = false;
  late TextEditingController _nameController;
  late String _assessedGender;
  late double _assessedAge;

  String? _selectedTrack;
  HealthPath? _selectedPath;
  List<ScreeningQuestion> _activeQuestions = [];
  final Map<String, dynamic> _answers = {};
  List<HealthInsight> _generatedInsights = [];

  bool _isAnalyzing = false;
  bool _showResult = false;
  int _score = 100;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientName);
    _assessedGender = widget.clientGender;
    _assessedAge = widget.clientAge;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onAnswer(String qId, dynamic value, int currentIndex) {
    HapticFeedback.lightImpact();
    _answers[qId] = value;

    if (currentIndex < _activeQuestions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      setState(() {});
    } else {
      _processResults();
    }
  }

  Future<void> _processResults() async {
    setState(() => _isAnalyzing = true);

    int penalty = 0;
    for (var q in _activeQuestions) {
      if (!_answers.containsKey(q.id)) continue;
      var ans = _answers[q.id];

      if (q.type == QuestionType.yesNo) {
        if (ans == "Yes") penalty += q.isRedFlag ? 20 : 10;
        if (q.id == 'protein_intake' && ans == "No") penalty += 15;
      } else if (q.type == QuestionType.singleChoice) {
        if (ans == "< 1.5 L" || ans == "Refined (Sunflower/Soy)" || ans == "Sedentary") penalty += 15;
        if (ans == "Late Night") penalty += 10;
      } else if (q.type == QuestionType.slider) {
        if (q.id == 'sleep_hrs' && (ans as double) < 6) penalty += 15;
      }
    }

    _score = (100 - penalty).clamp(15, 98);
    _generatedInsights = InsightEngine.analyze(_answers);

    try {
      await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).collection('assessments').add({
        'date': FieldValue.serverTimestamp(),
        'source': 'pureshift_app',
        'assessed_person': _nameController.text.trim(),
        'gender': _assessedGender,
        'age': _assessedAge,
        'track': _selectedTrack,
        'path': _selectedPath?.title,
        'score': _score,
        'answers': _answers,
      });
    } catch (e) {
      debugPrint("Failed to save assessment: $e");
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _showResult = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface, size: context.scale(24)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildCurrentView(context, theme, isDark),
        ),
      ),
    );
  }

  Widget _buildCurrentView(BuildContext context, ThemeData theme, bool isDark) {
    if (_showResult) return _buildResultDashboard(context, theme, isDark);
    if (_isAnalyzing) return _buildAnalyzingState(context, theme);
    if (!_isProfileSetupComplete) return _buildProfileSetup(context, theme, isDark);
    if (_selectedTrack == null) return _buildTrackSelection(context, theme, isDark);
    if (_selectedPath == null) return _buildPathSelection(context, theme, isDark);
    return _buildQuestionnaire(context, theme, isDark);
  }

  // --- VIEW 0: PROFILE SETUP ---
  Widget _buildProfileSetup(BuildContext context, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.scale(24.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ASSESSMENT DETAILS", style: TextStyle(color: clinicalSage, fontWeight: FontWeight.w900, letterSpacing: context.scale(1.5), fontSize: context.scale(11))),
          SizedBox(height: context.scale(8)),
          Text("Who is this assessment for?", style: TextStyle(fontSize: context.scale(28), fontWeight: FontWeight.bold, height: 1.2, color: theme.colorScheme.onSurface)),
          SizedBox(height: context.scale(32)),

          // Toggle for Self / Other
          Row(
            children: [
              Expanded(child: _buildPersonToggle(context, "Myself", true, theme, isDark)),
              SizedBox(width: context.scale(16)),
              Expanded(child: _buildPersonToggle(context, "Other", false, theme, isDark)),
            ],
          ),
          SizedBox(height: context.scale(32)),

          // Name Field
          if (!_isForSelf) ...[
            TextField(
              controller: _nameController,
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: context.scale(14)),
              decoration: InputDecoration(
                labelText: "Their Full Name",
                labelStyle: TextStyle(color: theme.hintColor, fontSize: context.scale(14)),
                prefixIcon: Icon(Icons.person_outline_rounded, color: theme.hintColor, size: context.scale(20)),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(16)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.scale(16)), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: context.scale(24)),
          ],

          // Gender Selection
          Text(_isForSelf ? "Your Biological Gender" : "Their Biological Gender", style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.bold, color: theme.hintColor)),
          SizedBox(height: context.scale(12)),
          Row(
            children: [
              Expanded(child: _buildGenderToggle(context, "Female", Icons.female_rounded, theme, isDark)),
              SizedBox(width: context.scale(16)),
              Expanded(child: _buildGenderToggle(context, "Male", Icons.male_rounded, theme, isDark)),
            ],
          ),
          SizedBox(height: context.scale(32)),

          // Age Slider
          Text(_isForSelf ? "Your Age: ${_assessedAge.toInt()} yrs" : "Their Age: ${_assessedAge.toInt()} yrs", style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.bold, color: theme.hintColor)),
          SizedBox(height: context.scale(12)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: context.scale(6), thumbShape: RoundSliderThumbShape(enabledThumbRadius: context.scale(10))),
            child: Slider(
              value: _assessedAge, min: 10, max: 90,
              activeColor: clinicalSage, inactiveColor: theme.dividerColor.withOpacity(0.2),
              onChanged: (v) => setState(() => _assessedAge = v),
            ),
          ),
          SizedBox(height: context.scale(48)),

          SizedBox(
            width: double.infinity, height: context.scale(56),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.onSurface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16)))),
              onPressed: () {
                if (!_isForSelf && _nameController.text.trim().isEmpty) return;
                setState(() => _isProfileSetupComplete = true);
              },
              child: Text("CONTINUE", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold, fontSize: context.scale(14), letterSpacing: context.scale(1.0))),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPersonToggle(BuildContext context, String label, bool isSelfValue, ThemeData theme, bool isDark) {
    bool isSelected = _isForSelf == isSelfValue;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isForSelf = isSelfValue;
          if (isSelfValue) {
            _nameController.text = widget.clientName;
            _assessedGender = widget.clientGender;
            _assessedAge = widget.clientAge;
          } else {
            _nameController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: context.scale(16)),
        decoration: BoxDecoration(
          color: isSelected ? clinicalSage.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(context.scale(16)),
          border: Border.all(color: isSelected ? clinicalSage : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelfValue ? Icons.person_rounded : Icons.group_add_rounded, color: isSelected ? clinicalSage : theme.hintColor, size: context.scale(20)),
            SizedBox(width: context.scale(8)),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.scale(14), color: isSelected ? clinicalSage : theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderToggle(BuildContext context, String label, IconData icon, ThemeData theme, bool isDark) {
    bool isSelected = _assessedGender == label;
    return GestureDetector(
      onTap: () => setState(() => _assessedGender = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: context.scale(16)),
        decoration: BoxDecoration(
          color: isSelected ? clinicalSage.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(context.scale(16)),
          border: Border.all(color: isSelected ? clinicalSage : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? clinicalSage : theme.hintColor, size: context.scale(20)),
            SizedBox(width: context.scale(8)),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.scale(14), color: isSelected ? clinicalSage : theme.hintColor)),
          ],
        ),
      ),
    );
  }

  // --- VIEW 1: TRACK SELECTION ---
  Widget _buildTrackSelection(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: EdgeInsets.all(context.scale(24.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CLINICAL DIAGNOSTICS", style: TextStyle(color: clinicalSage, fontWeight: FontWeight.w900, letterSpacing: context.scale(1.5), fontSize: context.scale(11))),
          SizedBox(height: context.scale(8)),
          Text("Choose Your Analysis Path, ${_nameController.text.split(' ').first}.", style: TextStyle(fontSize: context.scale(28), fontWeight: FontWeight.bold, height: 1.2, color: theme.colorScheme.onSurface)),
          SizedBox(height: context.scale(40)),
          _buildSelectionCard(
            context: context, title: "Clinical Condition Reversal", desc: "Focus on Diabetes, PCOS, Thyroid, or Hypertension.",
            icon: Icons.medical_services_outlined, onTap: () => setState(() => _selectedTrack = 'CLINICAL_REVERSAL'),
            theme: theme, isDark: isDark,
          ),
          SizedBox(height: context.scale(16)),
          _buildSelectionCard(
            context: context, title: "Weight & Metabolism", desc: "Focus on fat loss, muscle gain, and metabolic speed.",
            icon: Icons.monitor_weight_outlined, onTap: () => setState(() => _selectedTrack = 'WEIGHT_MGMT'),
            theme: theme, isDark: isDark,
          ),
        ],
      ),
    );
  }

  // --- VIEW 2: PATH SELECTION ---
  Widget _buildPathSelection(BuildContext context, ThemeData theme, bool isDark) {
    final availablePaths = AssessmentEngine.getAvailablePaths(_assessedAge, _assessedGender, _selectedTrack);
    return Padding(
      padding: EdgeInsets.all(context.scale(24.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Specific Area", style: TextStyle(fontSize: context.scale(24), fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          SizedBox(height: context.scale(24)),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: availablePaths.length,
              separatorBuilder: (_, __) => SizedBox(height: context.scale(16)),
              itemBuilder: (ctx, i) {
                final p = availablePaths[i];
                return _buildSelectionCard(
                  context: context, title: p.title, desc: p.description, icon: p.icon,
                  onTap: () {
                    setState(() {
                      _selectedPath = p;
                      _activeQuestions = AssessmentEngine.getFullQuestionSet(p);
                    });
                  }, theme: theme, isDark: isDark,
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // --- VIEW 3: QUESTIONNAIRE ---
  Widget _buildQuestionnaire(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeQuestions.length,
            itemBuilder: (ctx, index) {
              final q = _activeQuestions[index];
              return Padding(
                padding: EdgeInsets.all(context.scale(24.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: (index + 1) / _activeQuestions.length, backgroundColor: theme.dividerColor.withOpacity(0.1), color: clinicalSage, minHeight: context.scale(6), borderRadius: BorderRadius.circular(context.scale(4))),
                    SizedBox(height: context.scale(32)),
                    Text(q.text, style: TextStyle(fontSize: context.scale(26), fontWeight: FontWeight.bold, height: 1.3, color: theme.colorScheme.onSurface)),
                    const Spacer(),
                    if (q.type == QuestionType.yesNo) ...[
                      _buildAnswerButton(context, "Yes / Often", () => _onAnswer(q.id, "Yes", index), theme),
                      SizedBox(height: context.scale(16)),
                      _buildAnswerButton(context, "No / Rarely", () => _onAnswer(q.id, "No", index), theme),
                    ] else if (q.type == QuestionType.singleChoice) ...[
                      ...q.options!.map((opt) => Padding(padding: EdgeInsets.only(bottom: context.scale(16.0)), child: _buildAnswerButton(context, opt, () => _onAnswer(q.id, opt, index), theme)))
                    ] else if (q.type == QuestionType.slider) ...[
                      _buildSliderUI(context, q, index, theme),
                    ],
                    SizedBox(height: context.scale(40)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSliderUI(BuildContext context, ScreeningQuestion q, int index, ThemeData theme) {
    double tempVal = ((q.max ?? 100) + (q.min ?? 0)) / 2;
    return StatefulBuilder(
        builder: (ctx, setLocalState) {
          String displayValue = "${tempVal.toInt()} ${q.unit}";
          if (q.id == 'height') {
            int totalInches = (tempVal / 2.54).round();
            int feet = totalInches ~/ 12;
            int inches = totalInches % 12;
            displayValue = "$feet' $inches\" (${tempVal.toInt()} cm)";
          }

          return Column(
            children: [
              Text(displayValue, style: TextStyle(fontSize: q.id == 'height' ? context.scale(32) : context.scale(40), fontWeight: FontWeight.w900, color: clinicalSage)),
              SizedBox(height: context.scale(32)),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(trackHeight: context.scale(8), thumbShape: RoundSliderThumbShape(enabledThumbRadius: context.scale(12))),
                child: Slider(value: tempVal, min: q.min!, max: q.max!, activeColor: clinicalSage, inactiveColor: theme.dividerColor.withOpacity(0.2), onChanged: (v) => setLocalState(() => tempVal = v)),
              ),
              SizedBox(height: context.scale(40)),
              SizedBox(
                width: double.infinity, height: context.scale(56),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.onSurface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16)))),
                  onPressed: () => _onAnswer(q.id, tempVal, index),
                  child: Text("CONTINUE", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold, fontSize: context.scale(14), letterSpacing: context.scale(1.0))),
                ),
              )
            ],
          );
        }
    );
  }

  Widget _buildAnalyzingState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: EdgeInsets.all(context.scale(24)), decoration: BoxDecoration(color: clinicalSage.withOpacity(0.1), shape: BoxShape.circle), child: CircularProgressIndicator(color: clinicalSage, strokeWidth: context.scale(3))),
          SizedBox(height: context.scale(32)),
          Text("Analyzing Metabolic Patterns...", style: TextStyle(fontSize: context.scale(18), fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  // --- VIEW 4: RESULTS DASHBOARD ---
  Widget _buildResultDashboard(BuildContext context, ThemeData theme, bool isDark) {
    int riskScore = 100 - _score;
    Color riskColor = riskScore <= 20 ? const Color(0xFF10B981) : (riskScore <= 50 ? Colors.orange : Colors.redAccent);
    String riskVerdict = riskScore <= 20 ? "Low Metabolic Risk" : (riskScore <= 50 ? "Moderate Metabolic Stress" : "High Clinical Risk");

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(context.scale(24.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text("METABOLIC RISK ASSESSMENT", style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, letterSpacing: context.scale(1.5), fontSize: context.scale(11)))),
          SizedBox(height: context.scale(32)),

          Center(
            child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: context.scale(140), height: context.scale(140), child: CircularProgressIndicator(value: riskScore / 100, strokeWidth: context.scale(12), backgroundColor: theme.dividerColor.withOpacity(0.1), color: riskColor, strokeCap: StrokeCap.round)),
                  Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("$riskScore", style: TextStyle(fontSize: context.scale(42), fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, height: 1.0)),
                        Text("Risk Score", style: TextStyle(color: theme.hintColor, fontSize: context.scale(11), fontWeight: FontWeight.bold)),
                      ]
                  ),
                ]
            ),
          ),
          SizedBox(height: context.scale(32)),
          Center(child: Text(riskVerdict, style: TextStyle(fontSize: context.scale(22), fontWeight: FontWeight.bold, color: riskColor))),
          SizedBox(height: context.scale(12)),

          Container(
            margin: EdgeInsets.symmetric(vertical: context.scale(24)),
            padding: EdgeInsets.all(context.scale(16)),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(context.scale(12)), border: Border.all(color: Colors.amber.withOpacity(0.3))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.amber, size: context.scale(20)),
                SizedBox(width: context.scale(12)),
                Expanded(child: Text("This screening identifies metabolic possibilities and potential risk areas based on the provided symptoms. It is NOT a medical diagnosis.", style: TextStyle(color: theme.colorScheme.onSurface, fontSize: context.scale(12), fontWeight: FontWeight.w600, height: 1.4)))
              ],
            ),
          ),

          if (_generatedInsights.isNotEmpty) ...[
            Text("Identified Possibilities", style: TextStyle(fontSize: context.scale(18), fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            SizedBox(height: context.scale(16)),
            ..._generatedInsights.map((insight) => _buildInsightCard(context, insight, theme, isDark)),
            SizedBox(height: context.scale(32)),
          ],

          Container(
            padding: EdgeInsets.all(context.scale(24)),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(context.scale(24)), boxShadow: [BoxShadow(color: riskColor.withOpacity(0.2), blurRadius: 30, offset: Offset(0, context.scale(10)))]),
            child: Column(
              children: [
                Text("Check Another Family Member?", style: TextStyle(fontSize: context.scale(18), fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                SizedBox(height: context.scale(8)),
                Text("You can use this tool to assess the metabolic risk of your parents, spouse, or relatives.", style: TextStyle(color: Colors.white70, fontSize: context.scale(13)), textAlign: TextAlign.center),
                SizedBox(height: context.scale(24)),

                SizedBox(
                  width: double.infinity, height: context.scale(52),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isProfileSetupComplete = false;
                        _isForSelf = false;
                        _nameController.clear();
                        _assessedGender = "Female";
                        _assessedAge = 35.0;
                        _selectedTrack = null;
                        _selectedPath = null;
                        _activeQuestions = [];
                        _answers.clear();
                        _generatedInsights.clear();
                        _showResult = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16))), elevation: 0),
                    child: Text("START NEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: context.scale(13), letterSpacing: context.scale(0.5))),
                  ),
                ),
                SizedBox(height: context.scale(12)),
                SizedBox(
                  width: double.infinity, height: context.scale(52),
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16)))),
                    child: Text("DONE", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: context.scale(13), letterSpacing: context.scale(1.0))),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, HealthInsight insight, ThemeData theme, bool isDark) {
    final cardColor = insight.isCritical ? Colors.redAccent : Colors.orange;
    return Container(
      margin: EdgeInsets.only(bottom: context.scale(16)),
      padding: EdgeInsets.all(context.scale(20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121826) : Colors.white,
        borderRadius: BorderRadius.circular(context.scale(20)),
        border: Border.all(color: cardColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: Offset(0, context.scale(4)))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.isCritical ? Icons.warning_rounded : Icons.search_rounded, color: cardColor, size: context.scale(20)),
              SizedBox(width: context.scale(12)),
              Expanded(child: Text(insight.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.scale(15), color: theme.colorScheme.onSurface))),
            ],
          ),
          SizedBox(height: context.scale(12)),
          Text(insight.indicator, style: TextStyle(fontSize: context.scale(13), height: 1.5, color: theme.hintColor)),
          SizedBox(height: context.scale(12)),
          Container(
            padding: EdgeInsets.all(context.scale(12)),
            decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.05), borderRadius: BorderRadius.circular(context.scale(12))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.onSurface, size: context.scale(16)),
                SizedBox(width: context.scale(8)),
                Expanded(child: Text(insight.focusArea, style: TextStyle(fontSize: context.scale(13), fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, height: 1.4))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSelectionCard({required BuildContext context, required String title, required String desc, required IconData icon, required VoidCallback onTap, required ThemeData theme, required bool isDark}) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        padding: EdgeInsets.all(context.scale(20)),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF121826) : Colors.white, borderRadius: BorderRadius.circular(context.scale(20)), border: Border.all(color: theme.dividerColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 15, offset: Offset(0, context.scale(8)))]),
        child: Row(
          children: [
            Container(padding: EdgeInsets.all(context.scale(12)), decoration: BoxDecoration(color: clinicalSage.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: clinicalSage, size: context.scale(24))),
            SizedBox(width: context.scale(16)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.scale(16), color: theme.colorScheme.onSurface)), SizedBox(height: context.scale(4)), Text(desc, style: TextStyle(color: theme.hintColor, fontSize: context.scale(12)))])),
            Icon(Icons.arrow_forward_ios_rounded, size: context.scale(14), color: theme.hintColor.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButton(BuildContext context, String text, VoidCallback onTap, ThemeData theme) {
    return SizedBox(
      width: double.infinity, height: context.scale(60),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(side: BorderSide(color: theme.dividerColor.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16))), foregroundColor: theme.colorScheme.onSurface),
        child: Text(text, style: TextStyle(fontSize: context.scale(16), fontWeight: FontWeight.w600)),
      ),
    );
  }
}