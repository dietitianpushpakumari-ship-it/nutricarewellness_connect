// 🎯 DATA MODEL (DTO for Seeding)
class LabTestConfig {
  final String code;        // 🎯 NEW: Unique ID (e.g. 'hemoglobin')
  final String name;        // Renamed from displayName to match DB
  final String unit;
  final String category;
  final double? minRange;
  final double? maxRange;
  final bool isReverseLogic;

  const LabTestConfig({
    required this.code,
    required this.name,
    required this.unit,
    required this.category,
    this.minRange,
    this.maxRange,
    this.isReverseLogic = false,
  });

  // UI Helper (Optional)
  String get referenceRangeDisplay {
    if (minRange != null && maxRange != null) return '$minRange - $maxRange';
    if (maxRange != null) return '< $maxRange';
    if (minRange != null) return '> $minRange';
    return 'N/A';
  }
}

class LabVitalsData {
  // 1. Categories (Strict Order)
  static const List<String> labCategories1 = [
    'Hematology',
    'Iron Studies',
    'Inflammatory Markers',
    'Diabetic Profile',
    'Lipid Profile',
    'Thyroid Profile',
    'Liver Function',
    'Kidney Function',
    'Electrolytes',
    'Vitamins & Minerals',
    'Hormonal Profile',
    'Urine Analysis'
  ];

  // 2. Tests (Strict Order using List)
  static const List<LabTestConfig> allLabTests1 = [
    // --- Hematology ---
    LabTestConfig(code: 'hemoglobin', name: 'Hemoglobin', unit: 'g/dL', category: 'Hematology', minRange: 12.0, maxRange: 15.5),
    LabTestConfig(code: 'rbc_count', name: 'RBC Count', unit: 'mil/uL', category: 'Hematology', minRange: 4.5, maxRange: 5.5),
    LabTestConfig(code: 'wbc_count', name: 'WBC Count', unit: '/cumm', category: 'Hematology', minRange: 4000.0, maxRange: 11000.0),
    LabTestConfig(code: 'platelet_count', name: 'Platelet Count', unit: 'lakh/cumm', category: 'Hematology', minRange: 150000.0, maxRange: 450000.0),
    LabTestConfig(code: 'pcv', name: 'PCV / Hematocrit', unit: '%', category: 'Hematology', minRange: 36, maxRange: 46),
    LabTestConfig(code: 'mcv', name: 'MCV', unit: 'fL', category: 'Hematology', minRange: 80, maxRange: 96),
    LabTestConfig(code: 'mch', name: 'MCH', unit: 'pg', category: 'Hematology', minRange: 27, maxRange: 33),
    LabTestConfig(code: 'mchc', name: 'MCHC', unit: 'g/dL', category: 'Hematology', minRange: 32, maxRange: 36),
    LabTestConfig(code: 'rdw', name: 'RDW', unit: '%', category: 'Hematology', maxRange: 14.5),

    // --- Diabetic ---
    LabTestConfig(code: 'fbs', name: 'Fasting Blood Sugar', unit: 'mg/dL', category: 'Diabetic Profile', maxRange: 99.0),
    LabTestConfig(code: 'ppbs', name: 'Post Prandial (PPBS)', unit: 'mg/dL', category: 'Diabetic Profile', maxRange: 140.0),
    LabTestConfig(code: 'hba1c', name: 'HbA1c', unit: '%', category: 'Diabetic Profile', maxRange: 5.7),
    LabTestConfig(code: 'insulin_fasting', name: 'Insulin Fasting', unit: 'mIU/L', category: 'Diabetic Profile', maxRange: 25.0),
    LabTestConfig(code: 'random_bs', name: 'Random Blood Sugar', unit: 'mg/dL', category: 'Diabetic Profile', maxRange: 200),

    // --- Lipid Profile ---
    LabTestConfig(code: 'total_cholesterol', name: 'Total Cholesterol', unit: 'mg/dL', category: 'Lipid Profile', maxRange: 200.0),
    LabTestConfig(code: 'hdl_cholesterol', name: 'HDL (Good) Cholesterol', unit: 'mg/dL', category: 'Lipid Profile', minRange: 40.0, isReverseLogic: true),
    LabTestConfig(code: 'ldl_cholesterol', name: 'LDL (Bad) Cholesterol', unit: 'mg/dL', category: 'Lipid Profile', maxRange: 100.0),
    LabTestConfig(code: 'triglycerides', name: 'Triglycerides', unit: 'mg/dL', category: 'Lipid Profile', maxRange: 150.0),
    LabTestConfig(code: 'vldl', name: 'VLDL', unit: 'mg/dL', category: 'Lipid Profile', maxRange: 30),

    // --- Thyroid ---
    LabTestConfig(code: 'tsh', name: 'TSH', unit: 'uIU/mL', category: 'Thyroid Profile', minRange: 0.5, maxRange: 5),
    LabTestConfig(code: 't3', name: 'T3', unit: 'ng/dL', category: 'Thyroid Profile', minRange: 80, maxRange: 220),
    LabTestConfig(code: 't4', name: 'T4', unit: 'µg/dL', category: 'Thyroid Profile', minRange: 4.5, maxRange: 12),
    LabTestConfig(code: 'ft3', name: 'Free T3', unit: 'pg/mL', category: 'Thyroid Profile', minRange: 2.3, maxRange: 4.2),
    LabTestConfig(code: 'ft4', name: 'Free T4', unit: 'ng/dL', category: 'Thyroid Profile', minRange: 0.8, maxRange: 1.8),

    // --- Liver Function ---
    LabTestConfig(code: 'sgot', name: 'SGOT (AST)', unit: 'U/L', category: 'Liver Function', maxRange: 35),
    LabTestConfig(code: 'sgpt', name: 'SGPT (ALT)', unit: 'U/L', category: 'Liver Function', maxRange: 40),
    LabTestConfig(code: 'alp', name: 'Alkaline Phosphatase', unit: 'U/L', category: 'Liver Function', maxRange: 120),
    LabTestConfig(code: 'bilirubin_total', name: 'Total Bilirubin', unit: 'mg/dL', category: 'Liver Function', maxRange: 1.2),
    LabTestConfig(code: 'albumin', name: 'Serum Albumin', unit: 'g/dL', category: 'Liver Function', minRange: 3.5, maxRange: 5.0),
    LabTestConfig(code: 'total_protein', name: 'Total Protein', unit: 'g/dL', category: 'Liver Function', minRange: 6.0, maxRange: 8.3),

    // --- Kidney Function ---
    LabTestConfig(code: 'urea', name: 'Blood Urea', unit: 'mg/dL', category: 'Kidney Function', maxRange: 40),
    LabTestConfig(code: 'creatinine', name: 'Creatinine', unit: 'mg/dL', category: 'Kidney Function', maxRange: 1.2),
    LabTestConfig(code: 'uric_acid', name: 'Uric Acid', unit: 'mg/dL', category: 'Kidney Function', maxRange: 7),
    LabTestConfig(code: 'egfr', name: 'eGFR', unit: 'mL/min', category: 'Kidney Function', minRange: 90),

    // --- Vitamins ---
    LabTestConfig(code: 'vitamin_d', name: 'Vitamin D (25-OH)', unit: 'ng/mL', category: 'Vitamins & Minerals', minRange: 30),
    LabTestConfig(code: 'vitamin_b12', name: 'Vitamin B12', unit: 'pg/mL', category: 'Vitamins & Minerals', minRange: 200, maxRange: 900),
    LabTestConfig(code: 'folate', name: 'Folate', unit: 'ng/mL', category: 'Vitamins & Minerals', minRange: 4.0),
    LabTestConfig(code: 'calcium', name: 'Calcium', unit: 'mg/dL', category: 'Vitamins & Minerals', minRange: 8.5, maxRange: 10.2),
    LabTestConfig(code: 'magnesium', name: 'Magnesium', unit: 'mg/dL', category: 'Vitamins & Minerals', minRange: 1.7, maxRange: 2.2),
    LabTestConfig(code: 'zinc', name: 'Zinc', unit: 'µg/dL', category: 'Vitamins & Minerals', minRange: 70, maxRange: 120),

    // --- Urine Analysis ---
    LabTestConfig(code: 'urine_ph', name: 'Urine pH', unit: '', category: 'Urine Analysis', minRange: 4.5, maxRange: 8.0),
    LabTestConfig(code: 'urine_protein', name: 'Urine Protein', unit: 'mg/dL', category: 'Urine Analysis', maxRange: 150),

    // --- Electrolytes ---
    LabTestConfig(code: 'sodium', name: 'Sodium', unit: 'mmol/L', category: 'Electrolytes', minRange: 135, maxRange: 145),
    LabTestConfig(code: 'potassium', name: 'Potassium', unit: 'mmol/L', category: 'Electrolytes', minRange: 3.5, maxRange: 5.1),
    LabTestConfig(code: 'chloride', name: 'Chloride', unit: 'mmol/L', category: 'Electrolytes', minRange: 98, maxRange: 107),

    // --- Inflammatory ---
    LabTestConfig(code: 'crp', name: 'CRP', unit: 'mg/L', category: 'Inflammatory Markers', maxRange: 3.0),
    LabTestConfig(code: 'esr', name: 'ESR', unit: 'mm/hr', category: 'Inflammatory Markers', maxRange: 20),

    // --- Iron Studies ---
    LabTestConfig(code: 'serum_iron', name: 'Serum Iron', unit: 'mcg/dL', category: 'Iron Studies', minRange: 60, maxRange: 170),
    LabTestConfig(code: 'ferritin', name: 'Serum Ferritin', unit: 'ng/mL', category: 'Iron Studies', minRange: 15, maxRange: 150),
    LabTestConfig(code: 'tibc', name: 'TIBC', unit: 'mcg/dL', category: 'Iron Studies', minRange: 250, maxRange: 450),
    LabTestConfig(code: 'transferrin_saturation', name: 'Transferrin Saturation', unit: '%', category: 'Iron Studies', minRange: 20, maxRange: 50),

    // --- Hormonal Profile ---
    LabTestConfig(code: 'fsh', name: 'FSH', unit: 'mIU/mL', category: 'Hormonal Profile', minRange: 1.5, maxRange: 12.4),
    LabTestConfig(code: 'lh', name: 'LH', unit: 'mIU/mL', category: 'Hormonal Profile', minRange: 1.7, maxRange: 8.6),
    LabTestConfig(code: 'prolactin', name: 'Prolactin', unit: 'ng/mL', category: 'Hormonal Profile', minRange: 4.0, maxRange: 23.0),
    LabTestConfig(code: 'estrogen_estradiol', name: 'Estradiol (E2)', unit: 'pg/mL', category: 'Hormonal Profile', minRange: 30, maxRange: 400),
    LabTestConfig(code: 'progesterone', name: 'Progesterone', unit: 'ng/mL', category: 'Hormonal Profile', minRange: 0.2, maxRange: 25.0),
    LabTestConfig(code: 'testosterone_total', name: 'Total Testosterone', unit: 'ng/dL', category: 'Hormonal Profile', minRange: 300, maxRange: 1000),
    LabTestConfig(code: 'testosterone_free', name: 'Free Testosterone', unit: 'pg/mL', category: 'Hormonal Profile', minRange: 5, maxRange: 30),
    LabTestConfig(code: 'dhea_s', name: 'DHEA-S', unit: 'µg/dL', category: 'Hormonal Profile', minRange: 80, maxRange: 560),
    LabTestConfig(code: 'cortisol_morning', name: 'Cortisol (Morning)', unit: 'µg/dL', category: 'Hormonal Profile', minRange: 5, maxRange: 25),
    LabTestConfig(code: 'cortisol_evening', name: 'Cortisol (Evening)', unit: 'µg/dL', category: 'Hormonal Profile', minRange: 2, maxRange: 10),
    LabTestConfig(code: 'igf_1', name: 'IGF-1', unit: 'ng/mL', category: 'Hormonal Profile', minRange: 90, maxRange: 360),
    LabTestConfig(code: 'growth_hormone', name: 'Growth Hormone (GH)', unit: 'ng/mL', category: 'Hormonal Profile', minRange: 0.0, maxRange: 5.0),
    LabTestConfig(code: 'anti_tpo', name: 'Anti-TPO', unit: 'IU/mL', category: 'Hormonal Profile', maxRange: 35),
    LabTestConfig(code: 'anti_tg', name: 'Anti-Thyroglobulin', unit: 'IU/mL', category: 'Hormonal Profile', maxRange: 40),
  ];
}