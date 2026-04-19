extension StringCasingExtension on String {
  /// Capitalizes the first letter of every word and lowercases the rest.
  /// Example: "jOhn dOE" -> "John Doe"
  String toTitleCase() {
    if (trim().isEmpty) return this;

    return trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}