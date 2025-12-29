import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/geocoding_service.dart';
import '../services/open_charge_map_service.dart';
import '../theme/text_styles.dart';
import '../theme/colors.dart';

class RoutePlannerView extends StatefulWidget {
  const RoutePlannerView({super.key});

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  final _startController = TextEditingController();
  final _destinationController = TextEditingController();

  bool _useCurrentLocation = true;
  bool _loading = false;
  String? _error;

  int _stops = 1;
  double _arrivalPercent = 40;

  LatLng? _startLatLng;
  LatLng? _destinationLatLng;

  List<OcmStation> _plannedStops = [];

  // ---------------- LOCATION ----------------

  Future<LatLng> _getCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(pos.latitude, pos.longitude);
  }

  // ---------------- PLAN ROUTE ----------------

  Future<void> _planRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _plannedStops = [];
    });

    try {
      // START
      if (_useCurrentLocation) {
        _startLatLng = await _getCurrentLocation();
      } else {
        if (_startController.text.trim().isEmpty) {
          throw Exception("Enter start location");
        }

        _startLatLng = await GeocodingService.addressToLatLng(
          _startController.text,
        );
      }

      if (_startLatLng == null) {
        throw Exception("Start location not found");
      }

      // DESTINATION
      if (_destinationController.text.trim().isEmpty) {
        throw Exception("Enter destination");
      }

      _destinationLatLng = await GeocodingService.addressToLatLng(
        _destinationController.text,
      );

      if (_destinationLatLng == null) {
        throw Exception("Destination not found");
      }

      // BASIC FEASIBILITY CHECK
      if (_stops <= 0) {
        throw Exception("At least 1 charging stop is required");
      }

      // MIDPOINT-BASED STOP SEARCH
      final segments = _stops + 1;
      final latStep =
          (_destinationLatLng!.latitude - _startLatLng!.latitude) / segments;
      final lngStep =
          (_destinationLatLng!.longitude - _startLatLng!.longitude) / segments;

      final List<OcmStation> stops = [];

      for (int i = 1; i <= _stops; i++) {
        final mid = LatLng(
          _startLatLng!.latitude + latStep * i,
          _startLatLng!.longitude + lngStep * i,
        );

        final nearby = await OpenChargeMapService.fetchNearby(
          lat: mid.latitude,
          lng: mid.longitude,
          distanceKm: 30,
          maxResults: 1,
        );

        if (nearby.isEmpty) {
          throw Exception("More charging stops required for this plan");
        }

        stops.add(nearby.first);
      }

      setState(() {
        _plannedStops = stops;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- OPEN MAPS ----------------

  Future<void> _openInMaps() async {
    if (_startLatLng == null || _destinationLatLng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/'
      '${_startLatLng!.latitude},${_startLatLng!.longitude}/'
      '${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  enabled: !_useCurrentLocation,
                  decoration: const InputDecoration(labelText: "Start"),
                  onTap: () => setState(() => _useCurrentLocation = false),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: () {
                  setState(() {
                    _useCurrentLocation = true;
                    _startController.clear();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // DESTINATION
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(labelText: "Destination"),
          ),

          const SizedBox(height: 24),

          Text("Charging stops: $_stops"),
          Slider(
            value: _stops.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) => setState(() => _stops = v.round()),
          ),

          Text("Arrival battery: ${_arrivalPercent.round()}%"),
          Slider(
            value: _arrivalPercent,
            min: 10,
            max: 80,
            divisions: 7,
            onChanged: (v) => setState(() => _arrivalPercent = v),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _loading ? null : _planRoute,
            child: _loading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text("Plan Route"),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.caption),
          ],

          const SizedBox(height: 24),

          // STOP LIST
          if (_plannedStops.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Charging stops", style: AppTextStyles.title),
                const SizedBox(height: 8),
                ..._plannedStops.asMap().entries.map(
                  (e) => ListTile(
                    leading: const Icon(Icons.ev_station, color: Colors.green),
                    title: Text("Stop ${e.key + 1}: ${e.value.title}"),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openInMaps,
                  icon: const Icon(Icons.map),
                  label: const Text("Open in Maps"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
