import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../services/geocoding_service.dart';
import '../services/route_planner.dart';
import '../theme/text_styles.dart';
import '../theme/colors.dart';

class RoutePlannerView extends StatefulWidget {
  const RoutePlannerView({super.key});

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  final _startController = TextEditingController();
  final _destController = TextEditingController();
  final _stopsController = TextEditingController(text: "2");

  Timer? _startDebounce;
  Timer? _destDebounce;

  bool _loading = false;
  String? _error;

  bool _startUseCurrent = true;

  int _stops = 2;
  double _arrivalPercent = 40;

  LatLng? _startLatLng;
  LatLng? _destLatLng;

  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _destSuggestions = [];

  RoutePlanResult? _plan;

  double _vehicleRangeKm = 420;

  @override
  void initState() {
    super.initState();
    _bootstrapCurrentLocation();
  }

  @override
  void dispose() {
    _startController.dispose();
    _destController.dispose();
    _stopsController.dispose();
    _startDebounce?.cancel();
    _destDebounce?.cancel();
    super.dispose();
  }

  // ---------- LOCATION ----------
  Future<void> _bootstrapCurrentLocation() async {
    try {
      final pos = await _getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      _startLatLng = latLng;

      final name = await GeocodingService.reverseGeocode(latLng);
      if (!mounted) return;

      setState(() {
        _startUseCurrent = true;
        _startController.text = name ?? "Current location";
      });
    } catch (_) {}
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception("Location services are disabled");
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ---------- AUTOCOMPLETE ----------
  void _onStartChanged(String v) {
    _startUseCurrent = false;
    _startDebounce?.cancel();
    _startDebounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await GeocodingService.searchSuggestions(v, limit: 6);
      if (!mounted) return;
      setState(() => _startSuggestions = list);
    });
  }

  void _onDestChanged(String v) {
    _destDebounce?.cancel();
    _destDebounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await GeocodingService.searchSuggestions(v, limit: 6);
      if (!mounted) return;
      setState(() => _destSuggestions = list);
    });
  }

  void _selectStartSuggestion(PlaceSuggestion s) {
    setState(() {
      _startLatLng = s.point;
      _startController.text = s.displayName;
      _startSuggestions = [];
      _startUseCurrent = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _selectDestSuggestion(PlaceSuggestion s) {
    setState(() {
      _destLatLng = s.point;
      _destController.text = s.displayName;
      _destSuggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _useCurrentLocationAsStart() async {
    try {
      final pos = await _getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      _startLatLng = latLng;

      final name = await GeocodingService.reverseGeocode(latLng);
      if (!mounted) return;

      setState(() {
        _startUseCurrent = true;
        _startController.text = name ?? "Current location";
        _startSuggestions = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // ---------- PLAN ----------
  Future<void> _planRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
    });

    try {
      // Validate stops
      final stopsText = _stopsController.text.trim();
      final parsedStops = int.tryParse(stopsText);
      if (parsedStops == null || parsedStops < 1 || parsedStops > 100) {
        throw Exception("Charging stops must be between 1 and 100");
      }
      _stops = parsedStops;

      // Start
      if (_startUseCurrent) {
        final pos = await _getCurrentPosition();
        _startLatLng = LatLng(pos.latitude, pos.longitude);
      } else if (_startLatLng == null) {
        _startLatLng = await GeocodingService.addressToLatLng(
          _startController.text,
        );
      }

      if (_startLatLng == null) throw Exception("Start location not found");

      // Destination
      if (_destLatLng == null) {
        _destLatLng = await GeocodingService.addressToLatLng(
          _destController.text,
        );
      }

      if (_destLatLng == null) throw Exception("Destination not found");

      final result = await RoutePlannerService.plan(
        start: _startLatLng!,
        destination: _destLatLng!,
        stopsRequested: _stops,
        arrivalPercentTarget: _arrivalPercent.round(),
        vehicleRangeKm: _vehicleRangeKm,
      );

      setState(() => _plan = result);
      if (!result.ok) {
        setState(() => _error = result.message);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------- OPEN MAPS ----------
  Future<void> _openInMaps() async {
    final plan = _plan;
    if (plan == null || !plan.ok) return;

    final origin = '${_startLatLng!.latitude},${_startLatLng!.longitude}';
    final dest = '${_destLatLng!.latitude},${_destLatLng!.longitude}';

    final waypoints = plan.stops
        .map((s) => '${s.station.point.latitude},${s.station.point.longitude}')
        .join('|');

    final uri = Uri.parse('https://www.google.com/maps/dir/').replace(
      queryParameters: {
        'api': '1',
        'origin': origin,
        'destination': dest,
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
      },
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Route Planner", style: AppTextStyles.headline),
          const SizedBox(height: 16),

          // START
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  decoration: const InputDecoration(labelText: "Start"),
                  onChanged: _onStartChanged,
                  onTap: () => _startUseCurrent = false,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: _useCurrentLocationAsStart,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // DEST
          TextField(
            controller: _destController,
            decoration: const InputDecoration(labelText: "Destination"),
            onChanged: _onDestChanged,
          ),

          const SizedBox(height: 16),

          // STOPS
          Text("Charging stops (1–100)", style: AppTextStyles.caption),
          TextField(
            controller: _stopsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: 16),

          // ARRIVAL %
          Text("Arrival battery: ${_arrivalPercent.round()}%"),
          Slider(
            value: _arrivalPercent,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => setState(() => _arrivalPercent = v),
          ),

          if (_error != null) Text(_error!, style: AppTextStyles.caption),

          ElevatedButton(
            onPressed: _loading ? null : _planRoute,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text("Plan Route"),
          ),

          if (plan != null && plan.ok) ...[
            const SizedBox(height: 16),
            Text("Stops", style: AppTextStyles.title),
            ...plan.stops.map(
              (s) => Text(
                "• ${s.station.title} — %${s.departPercent}",
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _openInMaps,
              child: const Text("Open in Maps"),
            ),
          ],
        ],
      ),
    );
  }
}
