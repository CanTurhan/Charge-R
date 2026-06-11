import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'stations_view.dart';
import 'calculate_view.dart';
import 'route_planner_view.dart';
import 'profile_view.dart';
import '../theme/colors.dart';

class AppPageView extends StatefulWidget {
  const AppPageView({super.key});

  @override
  State<AppPageView> createState() => _AppPageViewState();
}

class _AppPageViewState extends State<AppPageView> {
  final PageController _controller = PageController();
  int _index = 0;

  // 🔴 SIRA: Stations, Calculate, Questions, Profile
  final _pages = const [
    StationsView(),
    CalculateView(),
    RoutePlannerView(),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationOnFirstLaunch();
  }

  Future<void> _requestLocationOnFirstLaunch() async {
    // 1️⃣ Location service açık mı?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    // 2️⃣ Permission durumu
    LocationPermission permission = await Geolocator.checkPermission();

    // 3️⃣ Daha önce sorulmadıysa sor
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    // deniedForever ise zorlamıyoruz
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white70,
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          _controller.jumpToPage(i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station),
            label: "Stations",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: "Calculate"),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: "Route",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
