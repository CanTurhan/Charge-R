import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/station_pin_marker.dart';
import '../services/open_charge_map_service.dart';
import '../theme/text_styles.dart';
import '../theme/colors.dart';

class StationsView extends StatefulWidget {
  const StationsView({super.key});

  @override
  State<StationsView> createState() => _StationsViewState();
}

class _StationsViewState extends State<StationsView> {
  final MapController _mapController = MapController();
  Timer? _mapMoveDebounce;

  bool _loading = false;
  String? _error;
  String? _permissionMessage;

  LatLng _center = const LatLng(41.0082, 28.9784);
  List<OcmStation> _stations = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialLocation();
    });
  }

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    super.dispose();
  }

  // ---------------- INITIAL LOCATION ----------------

  Future<void> _loadInitialLocation() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionMessage = null;
    });

    try {
      final hasPermission = await _ensureLocationPermission();

      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _permissionMessage =
              "To see nearby charging stations, please allow location access.";
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;

      setState(() {
        _center = latLng;
        _permissionMessage = null;
      });

      _mapController.move(latLng, 13);
      await _loadStationsForCenter(latLng);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _permissionMessage =
            "Location services are disabled. Please enable location services to see nearby charging stations.";
      });
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _showOpenSettingsDialog();
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ---------------- LOCATION BUTTON ----------------

  Future<void> _useMyLocation() async {
    await _loadInitialLocation();
  }

  // ---------------- OCM ----------------

  Future<void> _loadStationsForCenter(LatLng center) async {
    try {
      final stations = await OpenChargeMapService.fetchNearby(
        lat: center.latitude,
        lng: center.longitude,
        distanceKm: 20,
      );

      if (!mounted) return;
      setState(() => _stations = stations);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ---------------- NAVIGATION ----------------

  Future<void> _navigateToStation(LatLng point) async {
    final lat = point.latitude;
    final lng = point.longitude;

    final appleMaps = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');
    final googleMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(appleMaps)) {
      await launchUrl(appleMaps, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(googleMaps)) {
      await launchUrl(googleMaps, mode: LaunchMode.externalApplication);
    } else {
      throw Exception("No map application found");
    }
  }

  // ---------------- DETAIL ----------------

  void _openStationDetail(OcmStation station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(station.title, style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text("Charging station", style: AppTextStyles.caption),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToStation(station.point),
              icon: const Icon(Icons.navigation),
              label: const Text("Navigate"),
            ),
          ],
        ),
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Location Permission Needed"),
        content: const Text(
          "To see nearby charging stations, please enable location access in Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Stations", style: AppTextStyles.headline),
          ),

          if (_permissionMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(_permissionMessage!, style: AppTextStyles.caption),
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: AppTextStyles.caption),
            ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 12,
                    onPositionChanged: (pos, hasGesture) {
                      if (!hasGesture) return;

                      _mapMoveDebounce?.cancel();
                      _mapMoveDebounce = Timer(
                        const Duration(milliseconds: 700),
                        () {
                          final c = pos.center;
                          if (c != null) _loadStationsForCenter(c);
                        },
                      );
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.canturhan.charge_r',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 44,
                          height: 44,
                          point: _center,
                          child: const Icon(
                            Icons.my_location,
                            color: AppColors.accent,
                            size: 36,
                          ),
                        ),
                        ..._stations.map(
                          (s) => Marker(
                            width: 48,
                            height: 56,
                            point: s.point,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openStationDetail(s),
                              child: const StationPinMarker(size: 38),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _loading ? null : _useMyLocation,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Use my location"),
            ),
          ),
        ],
      ),
    );
  }
}
