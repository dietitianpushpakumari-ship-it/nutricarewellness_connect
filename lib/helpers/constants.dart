const Map<String, double> hydrationRanges = {
  "Less than 1 L": 0.5,
  "1 - 1.5 L": 1.25,
  "1.5 - 2 L": 1.75,
  "2 - 2.5 L": 2.25,
  "More than 2.5 L": 3.0,
};

const Map<String, int> stepRanges = {
  "Sedentary (0 - 2k)": 1000,
  "Low Active (2k - 4k)": 3000,
  "Active (4k - 6k)": 5000,
  "Very Active (6k - 10k)": 8000,
  "Athlete (> 10k)": 12000,
};