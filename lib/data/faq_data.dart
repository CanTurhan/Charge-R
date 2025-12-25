enum FAQCategory { general, calculation, battery, driving }

class FAQItem {
  final String question;
  final String answer;
  final FAQCategory category;

  const FAQItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class FAQData {
  static const List<FAQItem> items = [
    // ---------------- GENERAL ----------------
    FAQItem(
      category: FAQCategory.general,
      question: "What does Charge-R do?",
      answer:
          "Charge-R is an application that estimates the driving range of electric vehicles. The calculation is based on factors such as battery capacity, driving speed, driving mode, climate control usage, ambient temperature, and battery health.",
    ),

    FAQItem(
      category: FAQCategory.general,
      question: "Is Charge-R an official manufacturer application?",
      answer:
          "No. Charge-R is an independent range estimation tool and is not affiliated with any vehicle manufacturer. All results are provided for informational purposes only.",
    ),

    // ---------------- CALCULATION ----------------
    FAQItem(
      category: FAQCategory.calculation,
      question: "How is the driving range calculated?",
      answer:
          "The calculation is performed by evaluating multiple variables together, including battery capacity, average energy consumption, driving speed, climate control usage, ambient temperature, and battery health.",
    ),

    FAQItem(
      category: FAQCategory.calculation,
      question: "How accurate are these calculations?",
      answer:
          "The results are close to real-world usage averages. However, factors such as road inclination, wind conditions, traffic density, tire pressure, and driving style may affect the actual driving range.",
    ),

    FAQItem(
      category: FAQCategory.calculation,
      question: "Should the battery be charged to 100% before a long trip?",
      answer:
          "Yes. If a long-distance or uninterrupted drive is planned, manufacturers generally recommend charging the battery to 100% before departure.",
    ),

    // ---------------- BATTERY ----------------
    FAQItem(
      category: FAQCategory.battery,
      question: "What is the ideal battery charge range for daily use?",
      answer:
          "For daily use, keeping the battery charge level generally between 20% and 80% is recommended to support long-term battery health.",
    ),

    FAQItem(
      category: FAQCategory.battery,
      question: "Is it harmful to charge the battery to 100% all the time?",
      answer:
          "Continuously charging the battery to 100% during daily use may accelerate battery cell degradation over time. Therefore, 100% charging is typically recommended only before long trips.",
    ),

    FAQItem(
      category: FAQCategory.battery,
      question: "What is battery health?",
      answer:
          "Battery health refers to the current usable capacity of the battery compared to its original factory capacity. This value gradually decreases as the vehicle ages and mileage increases.",
    ),

    FAQItem(
      category: FAQCategory.battery,
      question: "What is the purpose of a heat pump?",
      answer:
          "A heat pump provides cabin heating using less energy, helping to reduce battery consumption. It is particularly beneficial in cold weather by minimizing range loss.",
    ),

    FAQItem(
      category: FAQCategory.battery,
      question: "Why does driving range decrease in cold weather?",
      answer:
          "In cold conditions, battery chemistry operates less efficiently, and cabin heating requires additional energy. These factors contribute to reduced driving range.",
    ),

    // ---------------- DRIVING ----------------
    FAQItem(
      category: FAQCategory.driving,
      question: "Why does driving range decrease at higher speeds?",
      answer:
          "At higher speeds, aerodynamic drag increases significantly. This causes higher energy consumption and results in reduced driving range.",
    ),

    FAQItem(
      category: FAQCategory.driving,
      question: "How much does climate control affect driving range?",
      answer:
          "Depending on power level and ambient temperature, climate control usage may reduce driving range by approximately 5% to 20%.",
    ),

    FAQItem(
      category: FAQCategory.driving,
      question: "What maintenance items are checked in electric vehicles?",
      answer:
          "In electric vehicles, components such as the battery system, software updates, tires, braking system, suspension, and thermal management systems are regularly inspected. Compared to internal combustion vehicles, electric vehicles have fewer mechanical components.",
    ),
  ];
}
