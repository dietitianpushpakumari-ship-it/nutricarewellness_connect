import 'package:flutter/material.dart';

// Model to hold static data for a single lab test
class LabTest {
  final String key; // Used as the key in the VitalsModel map
  final String displayName; // User-facing name
  final String unit; // Unit of measurement
  final String referenceRange; // The standard healthy range

  LabTest({
    required this.key,
    required this.displayName,
    required this.unit,
    required this.referenceRange,
  });
}

class LabVitalsData {
  // --- Master List of All Lab Tests ---
  static final Map<String, LabTest> allLabTests = {
    // 1. Diabetes Profile
    'fbs': LabTest(key: 'fbs', displayName: 'FBS', unit: 'mg/dL', referenceRange: '70 - 100'),
    'ppbs': LabTest(key: 'ppbs', displayName: 'PPBS', unit: 'mg/dL', referenceRange: '< 140'),
    'hba1c': LabTest(key: 'hba1c', displayName: 'HbA1c', unit: '%', referenceRange: '4.0 - 5.6'),

    // 2. Lipid Profile (Comprehensive)
    'cholesterol': LabTest(key: 'cholesterol', displayName: 'Total Cholesterol', unit: 'mg/dL', referenceRange: '< 200'),
    'triglycerides': LabTest(key: 'triglycerides', displayName: 'Triglycerides', unit: 'mg/dL', referenceRange: '< 150'),
    'hdl': LabTest(key: 'hdl', displayName: 'HDL', unit: 'mg/dL', referenceRange: '> 40 (M), > 50 (F)'),
    'ldl': LabTest(key: 'ldl', displayName: 'LDL', unit: 'mg/dL', referenceRange: '< 100'),
    'vldl': LabTest(key: 'vldl', displayName: 'VLDL', unit: 'mg/dL', referenceRange: '5 - 40'),
    'apoa1': LabTest(key: 'apoa1', displayName: 'Apo A1', unit: 'mg/dL', referenceRange: '100 - 160'),
    'apob': LabTest(key: 'apob', displayName: 'Apo B', unit: 'mg/dL', referenceRange: '60 - 130'),

    // 3. Renal Profile & Electrolytes 🎯 UPDATED GROUP
    'creatinine': LabTest(key: 'creatinine', displayName: 'Creatinine', unit: 'mg/dL', referenceRange: '0.6 - 1.2'),
    'bun': LabTest(key: 'bun', displayName: 'BUN', unit: 'mg/dL', referenceRange: '7 - 20'),
    'sodium': LabTest(key: 'sodium', displayName: 'Sodium', unit: 'mEq/L', referenceRange: '135 - 145'),
    'uric_acid': LabTest(key: 'uric_acid', displayName: 'Uric Acid', unit: 'mg/dL', referenceRange: '3.5 - 7.2'),

    // 4. Liver Function Tests (LFT)
    'sgpt': LabTest(key: 'sgpt', displayName: 'SGPT (ALT)', unit: 'U/L', referenceRange: '7 - 56'),
    'sgot': LabTest(key: 'sgot', displayName: 'SGOT (AST)', unit: 'U/L', referenceRange: '8 - 40'),
    'bilirubin': LabTest(key: 'bilirubin', displayName: 'Bilirubin (Total)', unit: 'mg/dL', referenceRange: '0.1 - 1.2'),
    'protein_total': LabTest(key: 'protein_total', displayName: 'Total Protein', unit: 'g/dL', referenceRange: '6.3 - 7.9'),

    // 5. Thyroid Status
    'thyroid_tsh': LabTest(key: 'thyroid_tsh', displayName: 'TSH', unit: 'mIU/L', referenceRange: '0.4 - 4.0'),

    // 6. Macronutrient Status (Protein Markers)
    'albumin': LabTest(key: 'albumin', displayName: 'Albumin', unit: 'g/dL', referenceRange: '3.5 - 5.0'),
    'globulin': LabTest(key: 'globulin', displayName: 'Globulin', unit: 'g/dL', referenceRange: '2.3 - 3.4'),
    'ag_ratio': LabTest(key: 'ag_ratio', displayName: 'A/G Ratio', unit: '', referenceRange: '1.2 - 2.2'),

    // 7. Micronutrient Status (Minerals and Vitamins)
    'iron': LabTest(key: 'iron', displayName: 'Iron (Serum)', unit: 'µg/dL', referenceRange: '60 - 170'),
    'tibc': LabTest(key: 'tibc', displayName: 'TIBC', unit: 'µg/dL', referenceRange: '250 - 450'),
    'tsat': LabTest(key: 'tsat', displayName: 'Transferrin Sat.', unit: '%', referenceRange: '20 - 50'),
    'ferritin': LabTest(key: 'ferritin', displayName: 'Ferritin', unit: 'ng/mL', referenceRange: '20 - 300'),
    'calcium': LabTest(key: 'calcium', displayName: 'Calcium (Total)', unit: 'mg/dL', referenceRange: '8.5 - 10.5'),
    'magnesium': LabTest(key: 'magnesium', displayName: 'Magnesium', unit: 'mg/dL', referenceRange: '1.7 - 2.2'),
    'zinc': LabTest(key: 'zinc', displayName: 'Zinc', unit: 'µg/dL', referenceRange: '70 - 120'),
    'vitamin_d': LabTest(key: 'vitamin_d', displayName: 'Vitamin D', unit: 'ng/mL', referenceRange: '30 - 100'),
    'vitamin_b12': LabTest(key: 'vitamin_b12', displayName: 'Vitamin B12', unit: 'pg/mL', referenceRange: '200 - 900'),

    // 8. Blood Count & Inflammation / Cardiac Risk 🎯 NEW/UPDATED GROUP
    'hemoglobin': LabTest(key: 'hemoglobin', displayName: 'Hemoglobin', unit: 'g/dL', referenceRange: '13.5-17.5 (M), 12.0-15.5 (F)'),
    'wbc': LabTest(key: 'wbc', displayName: 'WBC Count', unit: 'K/uL', referenceRange: '4.5 - 11.0'),
    'esr': LabTest(key: 'esr', displayName: 'ESR', unit: 'mm/hr', referenceRange: '< 20'),
    // Cardiac Risk Markers
    'crp': LabTest(key: 'crp', displayName: 'C-Reactive Protein (CRP)', unit: 'mg/L', referenceRange: '< 1.0'),
    'hs_crp': LabTest(key: 'hs_crp', displayName: 'hs-CRP (High-Sensitivity)', unit: 'mg/L', referenceRange: '< 1.0'), // Best indicator of cardiac inflammation
    'homocysteine': LabTest(key: 'homocysteine', displayName: 'Homocysteine', unit: 'µmol/L', referenceRange: '< 15'),
    'lpa': LabTest(key: 'lpa', displayName: 'Lipoprotein(a) (Lp(a))', unit: 'nmol/L', referenceRange: '< 75'),
  };

  // --- Grouping by Test Profile (Used for rendering) ---
  static const Map<String, List<String>> labTestGroups = {
    'Diabetes Profile': ['fbs', 'ppbs', 'hba1c'],
    'Lipid Profile (Comprehensive)': ['cholesterol', 'triglycerides', 'hdl', 'ldl', 'vldl', 'apoa1', 'apob'],
    'Renal Profile & Electrolytes': ['creatinine', 'bun', 'sodium', 'uric_acid'], // 🎯 UPDATED
    'Liver Function Tests (LFT)': ['sgpt', 'sgot', 'bilirubin', 'protein_total'],
    'Thyroid Status': ['thyroid_tsh'],
    'Macronutrient Status (Protein)': ['albumin', 'globulin', 'ag_ratio'],
    'Micronutrient Status (Minerals & Vitamins)': ['iron', 'tibc', 'tsat', 'ferritin', 'calcium', 'magnesium', 'zinc', 'vitamin_d', 'vitamin_b12'],
    'Blood Count & Cardiac Risk': ['hemoglobin', 'wbc', 'esr', 'crp', 'hs_crp', 'homocysteine', 'lpa'], // 🎯 UPDATED
  };

  // --- Icons for Groups (Used in Entry Screen) ---
  static const Map<String, IconData> groupIcons = {
    'Diabetes Profile': Icons.bloodtype,
    'Lipid Profile (Comprehensive)': Icons.opacity,
    'Renal Profile & Electrolytes': Icons.invert_colors, // 🎯 UPDATED
    'Liver Function Tests (LFT)': Icons.healing,
    'Thyroid Status': Icons.monitor_heart,
    'Macronutrient Status (Protein)': Icons.egg,
    'Micronutrient Status (Minerals & Vitamins)': Icons.ac_unit_sharp,
    'Blood Count & Cardiac Risk': Icons.favorite_border, // 🎯 UPDATED
  };

  // Helper to safely get test data
  static LabTest? getTest(String key) => allLabTests[key];
}