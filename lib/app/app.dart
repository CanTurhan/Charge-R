import 'package:flutter/material.dart';
import '../pages/page_view.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class ChargeRApp extends StatelessWidget {
  const ChargeRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Charge-R",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: "Inter",
        textTheme: const TextTheme(bodyMedium: AppTextStyles.body),
        colorScheme: const ColorScheme.dark(
          surface: AppColors.background,
          primary: AppColors.accent,
        ),
      ),
      home: const AppPageView(),
    );
  }
}
