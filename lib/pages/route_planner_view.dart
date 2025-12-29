import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Timer? _startDebounce;
  Timer? _destDebounce;

  bool _loading = false;
  String? _error;

  // UI state
  bool _startUseCurrent = true;

  int _stops = 2; // 1-100
  double _arrivalPercent = 40; // 0-100

  LatLng? _startLatLng;
  LatLng? _destLatLng;

  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _destSuggestions = [];

  RoutePlanResult? _plan;

  // --- VEHICLE RANGE (şimdilik stub) ---
  // Sonraki adım: Profile'dan araç modeli -> menzil çekilecek.
  // Şimdilik örnek: 420 km
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
    _startDebounce?.cancel();
    _destDebounce?.cancel();
    super.dispose();
  }

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
    } catch (_) {
      // sessiz geç; kullanıcı elle yazabilir
    }
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled");
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied forever");
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
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
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
    });

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
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
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
      // START
      if (_startUseCurrent) {
        final pos = await _getCurrentPosition();
        _startLatLng = LatLng(pos.latitude, pos.longitude);
      } else {
        if (_startLatLng == null) {
          final txt = _startController.text.trim();
          if (txt.isEmpty) throw Exception("Start location is required");
          _startLatLng = await GeocodingService.addressToLatLng(txt);
        }
      }

      if (_startLatLng == null) throw Exception("Start location not found");

      // DEST
      if (_destLatLng == null) {
        final txt = _destController.text.trim();
        if (txt.isEmpty) throw Exception("Destination is required");
        _destLatLng = await GeocodingService.addressToLatLng(txt);
      }

      if (_destLatLng == null) throw Exception("Destination not found");

      // Compute
      final result = await RoutePlannerService.plan(
        start: _startLatLng!,
        destination: _destLatLng!,
        stopsRequested: _stops,
        arrivalPercentTarget: _arrivalPercent.round(),
        vehicleRangeKm: _vehicleRangeKm,
      );

      if (!mounted) return;
      setState(() => _plan = result);

      if (!result.ok) {
        setState(() => _error = result.message ?? "Plan failed");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ---------- OPEN IN MAPS ----------
  Future<void> _openInMaps() async {
    final plan = _plan;
    if (plan == null || !plan.ok) return;

    // Basit: Google Maps Directions URL (waypoints)
    // https://www.google.com/maps/dir/?api=1&origin=..&destination=..&waypoints=..
    final origin = '${_startLatLng!.latitude},${_startLatLng!.longitude}';
    final dest = '${_destLatLng!.latitude},${_destLatLng!.longitude}';

    final waypoints = plan.stops
        .map((s) => '${s.station.point.latitude},${s.station.point.longitude}')
        .join('|');

    final googleUri = Uri.parse('https://www.google.com/maps/dir/').replace(
      queryParameters: {
        'api': '1',
        'origin': origin,
        'destination': dest,
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
        'travelmode': 'driving',
      },
    );

    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
      return;
    }

    // fallback Apple Maps
    final appleUri = Uri.parse(
      'http://maps.apple.com/',
    ).replace(queryParameters: {'saddr': origin, 'daddr': dest});
    await launchUrl(appleUri, mode: LaunchMode.externalApplication);
  }

  // ---------- UI HELPERS ----------
  Widget _suggestionList(
    List<PlaceSuggestion> list,
    void Function(PlaceSuggestion) onSelect,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final s = list[i];
          return ListTile(
            dense: true,
            title: Text(
              s.displayName,
              style: AppTextStyles.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(s),
          );
        },
      ),
    );
  }

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
                  decoration: const InputDecoration(
                    labelText: "Start",
                    hintText: "Current location or enter address",
                  ),
                  onChanged: _onStartChanged,
                  onTap: () => setState(() => _startUseCurrent = false),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Use current location",
                onPressed: _loading ? null : _useCurrentLocationAsStart,
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
          _suggestionList(_startSuggestions, _selectStartSuggestion),

          const SizedBox(height: 16),

          // DESTINATION
          TextField(
            controller: _destController,
            decoration: const InputDecoration(
              labelText: "Destination",
              hintText: "Kadıköy, Çankaya, Amsterdam, Big Ben...",
            ),
            onChanged: _onDestChanged,
          ),
          _suggestionList(_destSuggestions, _selectDestSuggestion),

          const SizedBox(height: 24),

          // STOPS (1-100)
          Text("Charging stops: $_stops", style: AppTextStyles.caption),
          Slider(
            value: _stops.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) => setState(() => _stops = v.round()),
          ),

          const SizedBox(height: 12),

          // ARRIVAL %
          Text(
            "Arrival battery: ${_arrivalPercent.round()}%",
            style: AppTextStyles.caption,
          ),
          Slider(
            value: _arrivalPercent,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => setState(() => _arrivalPercent = v),
          ),

          const SizedBox(height: 16),

          if (_error != null) ...[
            Text(_error!, style: AppTextStyles.caption),
            const SizedBox(height: 8),
          ],

          ElevatedButton(
            onPressed: _loading ? null : _planRoute,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Plan Route"),
          ),

          const SizedBox(height: 16),

          // RESULT
          if (plan != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Result", style: AppTextStyles.title),
                  const SizedBox(height: 8),
                  Text(
                    "Total distance: ${plan.totalDistanceKm.toStringAsFixed(1)} km",
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    "Requested stops: ${plan.requestedStops}",
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    "Min required stops: ${plan.requiredStopsMin}",
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 12),

                  if (plan.ok) ...[
                    Text("Stops & departure SOC", style: AppTextStyles.title),
                    const SizedBox(height: 8),
                    ...plan.stops.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "• ${s.station.title} — depart with %${s.departPercent}",
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openInMaps,
                      icon: const Icon(Icons.map),
                      label: const Text("Open in Maps"),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
