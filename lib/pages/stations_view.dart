import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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

  LatLng _center = const LatLng(41.0082, 28.9784); // İstanbul default
  List<OcmStation> _stations = [];

  // ---------------- LOCATION ----------------

  Future<void> _useMyLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showOpenSettingsDialog();
        return;
      }

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw Exception("Location permission denied");
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;

      setState(() => _center = latLng);
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

  // ---------------- UI ----------------

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Location Permission Needed"),
        content: const Text(
          "To use your location, please enable location access in Settings.",
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

  @override
  Widget build(BuildContext context) {
    final bool showEmptyState =
        !_loading && _error == null && _stations.isEmpty;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Stations", style: AppTextStyles.headline),
          ),

          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 12,
                    onPositionChanged: (position, hasGesture) {
                      if (!hasGesture) return;

                      _mapMoveDebounce?.cancel();
                      _mapMoveDebounce = Timer(
                        const Duration(milliseconds: 700),
                        () {
                          final c = position.center;
                          if (c != null) {
                            _loadStationsForCenter(c);
                          }
                        },
                      );
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.canturhan.charge_r',
                    ),
                    MarkerLayer(
                      markers: [
                        // Kullanıcı
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

                        // İstasyonlar
                        ..._stations.map(
                          (s) => Marker(
                            width: 36,
                            height: 36,
                            point: s.point,
                            child: const Icon(
                              Icons.ev_station,
                              color: Colors.greenAccent,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (showEmptyState)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        "Charging station data is temporarily unavailable.\n"
                        "Data provided by Open Charge Map.",
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _loading ? null : _useMyLocation,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Use my location"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
