import 'dart:math';
import 'package:latlong2/latlong.dart';

import 'directions_service.dart';
import 'open_charge_map_service.dart';

class PlannedStop {
  final OcmStation station;
  final int departPercent;

  PlannedStop({required this.station, required this.departPercent});
}

class RoutePlanResult {
  final bool ok;
  final String? message;

  final double totalDistanceKm;
  final int requestedStops;
  final int requiredStopsMin;
  final int arrivalPercentTarget;
  final List<PlannedStop> stops;

  const RoutePlanResult({
    required this.ok,
    required this.totalDistanceKm,
    required this.requestedStops,
    required this.requiredStopsMin,
    required this.arrivalPercentTarget,
    required this.stops,
    this.message,
  });
}

class RoutePlannerService {
  /// bacak km → gereken çıkış SOC %
  static int _requiredDepartPercent({
    required double legKm,
    required double fullRangeKm,
    required int arrivalTargetPercent,
  }) {
    final usagePercent = (legKm / fullRangeKm) * 100;
    final needed = usagePercent + arrivalTargetPercent;
    return min(100, needed.ceil());
  }

  static int _minStops({
    required double totalKm,
    required double fullRangeKm,
    required int arrivalTarget,
  }) {
    final usable = max(1, 100 - arrivalTarget);
    final maxLegKm = fullRangeKm * (usable / 100);

    if (maxLegKm <= 0) return 999;

    final legs = (totalKm / maxLegKm).ceil();
    return max(0, legs - 1);
  }

  static Future<RoutePlanResult> plan({
    required LatLng start,
    required LatLng destination,
    required int stopsRequested,
    required int arrivalPercentTarget,
    required double vehicleFullRangeKm,
  }) async {
    if (vehicleFullRangeKm <= 0) {
      return const RoutePlanResult(
        ok: false,
        totalDistanceKm: 0,
        requestedStops: 0,
        requiredStopsMin: 0,
        arrivalPercentTarget: 0,
        stops: [],
        message: 'Vehicle range invalid',
      );
    }

    final totalKm = await DirectionsService.getRouteDistanceKm(
      start,
      destination,
    );

    final minStops = _minStops(
      totalKm: totalKm,
      fullRangeKm: vehicleFullRangeKm,
      arrivalTarget: arrivalPercentTarget,
    );

    if (stopsRequested < minStops) {
      return RoutePlanResult(
        ok: false,
        totalDistanceKm: totalKm,
        requestedStops: stopsRequested,
        requiredStopsMin: minStops,
        arrivalPercentTarget: arrivalPercentTarget,
        stops: const [],
        message: 'Minimum required stops: $minStops',
      );
    }

    final legs = stopsRequested + 1;
    final legKm = totalKm / legs;

    final List<PlannedStop> stops = [];
    final usedIds = <int>{};

    for (int i = 1; i <= stopsRequested; i++) {
      final t = i / legs;
      final sample = LatLng(
        start.latitude + (destination.latitude - start.latitude) * t,
        start.longitude + (destination.longitude - start.longitude) * t,
      );

      final stations = await OpenChargeMapService.fetchNearby(
        lat: sample.latitude,
        lng: sample.longitude,
        distanceKm: 25,
        maxResults: 20,
      );

      OcmStation? chosen;
      for (final s in stations) {
        if (!usedIds.contains(s.id)) {
          chosen = s;
          break;
        }
      }

      if (chosen == null) {
        return RoutePlanResult(
          ok: false,
          totalDistanceKm: totalKm,
          requestedStops: stopsRequested,
          requiredStopsMin: minStops,
          arrivalPercentTarget: arrivalPercentTarget,
          stops: stops,
          message: 'Charging station not found on route',
        );
      }

      usedIds.add(chosen.id);

      final nextArrival = (i == stopsRequested) ? arrivalPercentTarget : 10;

      final depart = _requiredDepartPercent(
        legKm: legKm,
        fullRangeKm: vehicleFullRangeKm,
        arrivalTargetPercent: nextArrival,
      );

      stops.add(PlannedStop(station: chosen, departPercent: depart));
    }

    return RoutePlanResult(
      ok: true,
      totalDistanceKm: totalKm,
      requestedStops: stopsRequested,
      requiredStopsMin: minStops,
      arrivalPercentTarget: arrivalPercentTarget,
      stops: stops,
    );
  }
}
