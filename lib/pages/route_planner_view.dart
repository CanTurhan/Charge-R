import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/geocoding_service.dart';
import '../services/route_planner.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class RoutePlannerView extends StatefulWidget {
  const RoutePlannerView({super.key});

  @override
  State<RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<RoutePlannerView> {
  final _startController = TextEditingController();
  final _destController = TextEditingController();
  final _stopsController = TextEditingController(text: '2');

  Timer? _startDebounce;
  Timer? _destDebounce;

  bool _loading = false;
  String? _error;

  bool _useCurrentStart = true;

  int _stops = 2;
  double _arrivalPercent = 40;

  LatLng? _startLatLng;
  LatLng? _destLatLng;

  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _destSuggestions = [];

  RoutePlanResult? _plan;

  // geçici — profile’dan çekilecek
  final double _vehicleRangeKm = 420;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
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

  // ---------------- LOCATION ----------------

  Future<void> _initCurrentLocation() async {
    try {
      final pos = await _getCurrentPosition();
      _startLatLng = LatLng(pos.latitude, pos.longitude);

      final name = await GeocodingService.reverseGeocode(_startLatLng!);
      if (!mounted) return;

      setState(() {
        _useCurrentStart = true;
        _startController.text = name ?? 'Current location';
      });
    } catch (_) {}
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ---------------- AUTOCOMPLETE ----------------

  void _onStartChanged(String v) {
    _useCurrentStart = false;
    _startDebounce?.cancel();
    _startDebounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await GeocodingService.searchSuggestions(v);
      if (!mounted) return;
      setState(() => _startSuggestions = list);
    });
  }

  void _onDestChanged(String v) {
    _destDebounce?.cancel();
    _destDebounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await GeocodingService.searchSuggestions(v);
      if (!mounted) return;
      setState(() => _destSuggestions = list);
    });
  }

  Widget _suggestions(
    List<PlaceSuggestion> list,
    void Function(PlaceSuggestion) onSelect,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
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

  // ---------------- PLAN ----------------

  Future<void> _planRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
    });

    try {
      _stops = int.parse(_stopsController.text);
      if (_stops < 1 || _stops > 100) {
        throw Exception('Charging stops must be between 1 and 100');
      }

      if (_useCurrentStart) {
        final pos = await _getCurrentPosition();
        _startLatLng = LatLng(pos.latitude, pos.longitude);
      } else if (_startLatLng == null) {
        _startLatLng = await GeocodingService.addressToLatLng(
          _startController.text,
        );
      }

      if (_startLatLng == null) throw Exception('Start not found');

      if (_destLatLng == null) {
        _destLatLng = await GeocodingService.addressToLatLng(
          _destController.text,
        );
      }

      if (_destLatLng == null) throw Exception('Destination not found');

      final result = await RoutePlannerService.plan(
        start: _startLatLng!,
        destination: _destLatLng!,
        stopsRequested: _stops,
        arrivalPercentTarget: _arrivalPercent.round(),
        vehicleRangeKm: _vehicleRangeKm,
      );

      setState(() => _plan = result);
      if (!result.ok) _error = result.message;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- MAPS ----------------

  Future<void> _openInMaps() async {
    if (_plan == null || !_plan!.ok) return;

    final origin = '${_startLatLng!.latitude},${_startLatLng!.longitude}';
    final dest = '${_destLatLng!.latitude},${_destLatLng!.longitude}';

    final waypoints = _plan!.stops
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

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Route Planner', style: AppTextStyles.headline),

          const SizedBox(height: 16),

          TextField(
            controller: _startController,
            decoration: const InputDecoration(labelText: 'Start'),
            onChanged: _onStartChanged,
            onTap: () => _useCurrentStart = false,
          ),
          _suggestions(_startSuggestions, (s) {
            _startLatLng = s.point;
            _startController.text = s.displayName;
            _startSuggestions = [];
            _useCurrentStart = false;
            setState(() {});
          }),

          const SizedBox(height: 12),

          TextField(
            controller: _destController,
            decoration: const InputDecoration(labelText: 'Destination'),
            onChanged: _onDestChanged,
          ),
          _suggestions(_destSuggestions, (s) {
            _destLatLng = s.point;
            _destController.text = s.displayName;
            _destSuggestions = [];
            setState(() {});
          }),

          const SizedBox(height: 12),

          TextField(
            controller: _stopsController,
            decoration: const InputDecoration(
              labelText: 'Charging stops (1–100)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: 12),

          Text('Arrival battery: ${_arrivalPercent.round()}%'),
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
                : const Text('Plan Route'),
          ),

          if (_plan != null && _plan!.ok) ...[
            const SizedBox(height: 16),
            Text('Stops', style: AppTextStyles.title),
            ..._plan!.stops.map(
              (s) => Text(
                '• ${s.station.title} — %${s.departPercent}',
                style: AppTextStyles.caption,
              ),
            ),
            ElevatedButton(
              onPressed: _openInMaps,
              child: const Text('Open in Maps'),
            ),
          ],
        ],
      ),
    );
  }
}
