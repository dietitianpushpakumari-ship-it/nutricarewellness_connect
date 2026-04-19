import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/core/localization/language_config.dart';
import 'language_provider.dart';

class LanguageSelectorSheet extends ConsumerWidget {
  const LanguageSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(languageProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Language",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Generate list from supportedLanguages map
          ...supportedLanguages.entries.map((entry) {
            final code = entry.key;
            final name = entry.value;
            final isSelected = currentLocale.languageCode == code;

            return ListTile(
              onTap: () {
                // 🎯 Update Global State
                ref.read(languageProvider.notifier).changeLanguage(code);
                Navigator.pop(context);
              },
              leading: CircleAvatar(
                backgroundColor: isSelected ? Colors.teal.shade50 : Colors.grey.shade100,
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.teal : Colors.grey
                  ),
                ),
              ),
              title: Text(
                name,
                style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.teal : Colors.black87
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.teal)
                  : null,
            );
          }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}