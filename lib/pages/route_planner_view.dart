import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../services/geocoding_service.dart';
import '../services/open_charge_map_service.dart';
import '../utils/route_utils.dart';
import '../theme/text_styles.dart';

class RoutePlannerView extends StatefulWidget {
  const RoutePlannerView({super.key});

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool _useCurrentLocation = true;
  bool _loading = false;
  String? _error;

  int _stops = 2;
  double _arrivalPercent = 40;

  LatLng? _startLatLng;
  LatLng? _destinationLatLng;

  // ---------------- CURRENT LOCATION ----------------

  Future<void> _setCurrentLocationAsStart() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _useCurrentLocation = true;
      _startLatLng = LatLng(pos.latitude, pos.longitude);
      _startController.text = "Current location";
    });
  }

  // ---------------- PLAN ROUTE ----------------

  Future<void> _planRoute() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // START
      if (_useCurrentLocation) {
        if (_startLatLng == null) {
          await _setCurrentLocationAsStart();
        }
      } else {
        if (_startController.text.trim().isEmpty) {
          throw Exception("Enter a start location");
        }

        _startLatLng = await GeocodingService.addressToLatLng(
          _startController.text,
        );

        if (_startLatLng == null) {
          throw Exception("Start location not found");
        }
      }

      // DESTINATION
      if (_destinationController.text.trim().isEmpty) {
        throw Exception("Enter a destination");
      }

      _destinationLatLng = await GeocodingService.addressToLatLng(
        _destinationController.text,
      );

      if (_destinationLatLng == null) {
        throw Exception("Destination not found");
      }

      // STOPS
      final stops = RouteUtils.splitRoute(
        start: _startLatLng!,
        end: _destinationLatLng!,
        stops: _stops,
      );

      for (int i = 0; i < stops.length; i++) {
        final station = await OpenChargeMapService.findClosestStation(
          lat: stops[i].latitude,
          lng: stops[i].longitude,
        );

        debugPrint("STOP ${i + 1}: ${station?.title}");
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Route Planner", style: AppTextStyles.headline),
          const SizedBox(height: 24),

          // START
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  decoration: const InputDecoration(
                    labelText: "Start",
                    hintText: "Current location or address",
                  ),
                  onChanged: (_) {
                    if (_useCurrentLocation) {
                      setState(() => _useCurrentLocation = false);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: _setCurrentLocationAsStart,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // DESTINATION
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(
              labelText: "Destination",
              hintText: "City, street, country",
            ),
          ),

          const SizedBox(height: 24),

          Text("Charging stops: $_stops"),
          Slider(
            value: _stops.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (v) => setState(() => _stops = v.round()),
          ),

          const SizedBox(height: 16),

          Text("Arrival battery: ${_arrivalPercent.round()}%"),
          Slider(
            value: _arrivalPercent,
            min: 10,
            max: 80,
            divisions: 7,
            onChanged: (v) => setState(() => _arrivalPercent = v),
          ),

          const SizedBox(height: 24),

          if (_error != null) Text(_error!, style: AppTextStyles.caption),

          ElevatedButton(
            onPressed: _loading ? null : _planRoute,
            child: _loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text("Plan Route"),
          ),
        ],
      ),
    );
  }
}
