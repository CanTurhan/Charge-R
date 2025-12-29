import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class RoutePlannerView extends StatefulWidget {
  const RoutePlannerView({super.key});

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool _usingCurrentLocation = true;
  bool _loadingLocation = false;

  int _stops = 2;
  double _arrivalPercent = 40;

  String? _error;

  @override
  void initState() {
    super.initState();
    _setCurrentLocationAsStart();
  }

  // ---------------- LOCATION ----------------

  Future<void> _setCurrentLocationAsStart() async {
    setState(() {
      _loadingLocation = true;
      _usingCurrentLocation = true;
      _error = null;
    });

    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = "Location permission denied");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _startController.text =
            "Current location (${pos.latitude.toStringAsFixed(4)}, "
            "${pos.longitude.toStringAsFixed(4)})";
      });
    } catch (_) {
      setState(() => _error = "Failed to get current location");
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  // ---------------- ACTION ----------------

  void _onCalculate() {
    setState(() => _error = null);

    if (_destinationController.text.trim().isEmpty) {
      setState(() => _error = "Please enter a destination");
      return;
    }

    if (_stops == 0 && _arrivalPercent > 50) {
      setState(() {
        _error =
            "Arriving with ${_arrivalPercent.round()}% without charging stops "
            "is likely not possible.";
      });
      return;
    }

    // Şimdilik sadece logluyoruz
    debugPrint("START: ${_startController.text}");
    debugPrint("DESTINATION: ${_destinationController.text}");
    debugPrint("STOPS: $_stops");
    debugPrint("ARRIVAL %: ${_arrivalPercent.round()}");
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Route Planner", style: AppTextStyles.headline),
            const SizedBox(height: 24),

            // ---------- START ----------
            Text("Start", style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startController,
                    onChanged: (_) {
                      setState(() => _usingCurrentLocation = false);
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.place),
                      hintText: "Current location or enter address",
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Use current location",
                  onPressed: _loadingLocation
                      ? null
                      : _setCurrentLocationAsStart,
                  icon: _loadingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.my_location,
                          color: _usingCurrentLocation
                              ? AppColors.accent
                              : Colors.white70,
                        ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ---------- DESTINATION ----------
            Text("Destination", style: AppTextStyles.caption),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.flag),
                hintText: "Enter destination",
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ---------- STOPS ----------
            Text("Charging stops", style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _stops > 0 ? () => setState(() => _stops--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text("$_stops", style: AppTextStyles.title),
                IconButton(
                  onPressed: () => setState(() => _stops++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ---------- ARRIVAL ----------
            Text("Arrival battery (%)", style: AppTextStyles.caption),
            Slider(
              value: _arrivalPercent,
              min: 10,
              max: 80,
              divisions: 14,
              label: "${_arrivalPercent.round()}%",
              onChanged: (v) => setState(() => _arrivalPercent = v),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.caption),
            ],

            const SizedBox(height: 32),

            // ---------- CALCULATE ----------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onCalculate,
                child: const Text("Calculate route"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
