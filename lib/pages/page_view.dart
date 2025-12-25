import 'package:flutter/material.dart';
import 'calculate_view.dart';
import 'questions_view.dart';
import 'profile_view.dart';

class AppPageView extends StatefulWidget {
  const AppPageView({super.key});

  @override
  State<AppPageView> createState() => _AppPageViewState();
}

class _AppPageViewState extends State<AppPageView> {
  final PageController _controller = PageController();
  int _index = 0;

  final _pages = const [CalculateView(), QuestionsView(), ProfileView()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          _controller.jumpToPage(i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: "Calculate"),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: "Questions",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
