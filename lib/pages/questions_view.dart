import 'package:flutter/material.dart';
import '../data/faq_data.dart';
import '../theme/text_styles.dart';
import '../theme/colors.dart';

class QuestionsView extends StatefulWidget {
  const QuestionsView({super.key});

  @override
  State<QuestionsView> createState() => _QuestionsViewState();
}

class _QuestionsViewState extends State<QuestionsView> {
  String search = "";
  FAQCategory? selectedCategory;

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  @override
  Widget build(BuildContext context) {
    final q = _normalize(search);

    final filtered = FAQData.items.where((item) {
      final question = _normalize(item.question);
      final answer = _normalize(item.answer);

      final matchesSearch =
          q.isEmpty || question.contains(q) || answer.contains(q);

      final matchesCategory =
          selectedCategory == null || item.category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- HEADER WITH LOGO ----------
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    "assets/app_icon.png",
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text("Questions", style: AppTextStyles.headline),
              ],
            ),

            const SizedBox(height: 16),

            // SEARCH
            TextField(
              decoration: const InputDecoration(
                hintText: "Search a question...",
              ),
              onChanged: (v) => setState(() => search = v),
            ),

            const SizedBox(height: 12),

            // CATEGORY FILTER
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip("All", null),
                  _chip("General", FAQCategory.general),
                  _chip("Calculation", FAQCategory.calculation),
                  _chip("Battery", FAQCategory.battery),
                  _chip("Driving", FAQCategory.driving),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        "No matching questions found.",
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView(
                      children: filtered.map((f) {
                        return Card(
                          color: AppColors.surface,
                          child: ExpansionTile(
                            title: Text(f.question),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  f.answer,
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 12),

            // ---------- DISCLAIMER ----------
            const Text(
              "The information provided here is for general guidance only. "
              "Actual driving range and vehicle behavior may vary depending on "
              "road conditions, driving style, weather, and vehicle condition.",
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, FAQCategory? category) {
    final selected = selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => selectedCategory = category);
        },
      ),
    );
  }
}
