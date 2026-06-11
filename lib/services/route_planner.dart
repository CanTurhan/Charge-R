import 'dart:math';
import 'package:latlong2/latlong.dart';

import '../services/open_charge_map_service.dart';

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

  RoutePlanResult({
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
  static const Distance _distance = Distance();

  /// Basit fizik: (km / rangeKm) * 100 = SOC tüketimi.
  /// Final varışta targetArrival% kalacak şekilde her bacak için gereken çıkış %.
  static int _requiredDepartPercent({
    required double legKm,
    required double rangeKm,
    required int arrivalTargetPercent,
  }) {
    final need = (legKm / rangeKm) * 100.0 + arrivalTargetPercent;
    return min(100, need.ceil());
  }

  /// Kaç durak MIN gerekir (100% ile çıkıp her bacakta finalde targetArrival kalacak varsayımı)
  static int minStopsNeeded({
    required double totalKm,
    required double rangeKm,
    required int arrivalTargetPercent,
  }) {
    // 100% ile çıkıldığında bir bacakta efektif kullanılabilir SOC = (100 - arrivalTarget)
    final usable = max(1, 100 - arrivalTargetPercent);
    final maxLegKm = rangeKm * (usable / 100.0);

    if (maxLegKm <= 0.0) return 999;

    final legsNeeded = (totalKm / maxLegKm).ceil(); // örn 3 bacak
    final stops = max(0, legsNeeded - 1); // bacak-1 = durak
    return stops;
  }

  /// Düz çizgi üzerinde n eşit ara nokta alıp OCM’den yakın istasyon çekerek durak isimleri üretir.
  /// (Google/Apple route çizimi yok; sadece “Plan Route altında liste” hedefi.)
  static Future<RoutePlanResult> plan({
    required LatLng start,
    required LatLng destination,
    required int stopsRequested,
    required int arrivalPercentTarget,
    required double vehicleRangeKm,
  }) async {
    // VALIDATION
    if (stopsRequested < 1 || stopsRequested > 100) {
      return RoutePlanResult(
        ok: false,
        totalDistanceKm: 0,
        requestedStops: stopsRequested,
        requiredStopsMin: 0,
        arrivalPercentTarget: arrivalPercentTarget,
        stops: [],
        message: "Geçersiz durak sayısı (1-100)",
      );
    }

    if (arrivalPercentTarget < 0 || arrivalPercentTarget > 100) {
      return RoutePlanResult(
        ok: false,
        totalDistanceKm: 0,
        requestedStops: stopsRequested,
        requiredStopsMin: 0,
        arrivalPercentTarget: arrivalPercentTarget,
        stops: [],
        message: "Geçersiz varış yüzdesi (0-100)",
      );
    }

    if (vehicleRangeKm <= 0) {
      return RoutePlanResult(
        ok: false,
        totalDistanceKm: 0,
        requestedStops: stopsRequested,
        requiredStopsMin: 0,
        arrivalPercentTarget: arrivalPercentTarget,
        stops: [],
        message: "Araç menzili bulunamadı",
      );
    }

    final totalKm = _distance.as(LengthUnit.Kilometer, start, destination);

    final requiredMin = minStopsNeeded(
      totalKm: totalKm,
      rangeKm: vehicleRangeKm,
      arrivalTargetPercent: arrivalPercentTarget,
    );

    if (stopsRequested < requiredMin) {
      return RoutePlanResult(
        ok: false,
        totalDistanceKm: totalKm,
        requestedStops: stopsRequested,
        requiredStopsMin: requiredMin,
        arrivalPercentTarget: arrivalPercentTarget,
        stops: [],
        message: "Bu plan için en az $requiredMin durak gerekiyor.",
      );
    }

    // LEG distances (equal split)
    final legs = stopsRequested + 1;
    final legKm = totalKm / legs;

    // Generate stops (sample points along straight line)
    final List<PlannedStop> plannedStops = [];
    final usedIds = <int>{};

    for (int i = 1; i <= stopsRequested; i++) {
      final t = i / legs;

      final sample = LatLng(
        start.latitude + (destination.latitude - start.latitude) * t,
        start.longitude + (destination.longitude - start.longitude) * t,
      );

      // search near sample
      final candidates = await OpenChargeMapService.fetchNearby(
        lat: sample.latitude,
        lng: sample.longitude,
        distanceKm: 10, // daralt, daha anlamlı
        maxResults: 30,
      );

      // pick first unused
      OcmStation? chosen;
      for (final c in candidates) {
        if (!usedIds.contains(c.id)) {
          chosen = c;
          break;
        }
      }

      // hiç bulamazsa: sample noktasını "fake" gibi koymayalım; o zaman boş title ile dönmeyelim
      if (chosen == null) {
        // fallback: daha geniş ara
        final fallback = await OpenChargeMapService.fetchNearby(
          lat: sample.latitude,
          lng: sample.longitude,
          distanceKm: 30,
          maxResults: 30,
        );
        for (final c in fallback) {
          if (!usedIds.contains(c.id)) {
            chosen = c;
            break;
          }
        }
      }

      if (chosen == null) {
        return RoutePlanResult(
          ok: false,
          totalDistanceKm: totalKm,
          requestedStops: stopsRequested,
          requiredStopsMin: requiredMin,
          arrivalPercentTarget: arrivalPercentTarget,
          stops: plannedStops,
          message:
              "Bazı segmentlerde şarj istasyonu bulunamadı. Durak sayısını değiştir veya farklı güzergâh dene.",
        );
      }

      usedIds.add(chosen.id);

      // departure % for NEXT leg:
      // intermediate legs: bir sonraki stopa vardığında %10 kalsın; final leg: hedef arrivalPercentTarget
      final isLastStop = (i == stopsRequested);
      final nextArrival = isLastStop ? arrivalPercentTarget : 10;

      final depart = _requiredDepartPercent(
        legKm: legKm,
        rangeKm: vehicleRangeKm,
        arrivalTargetPercent: nextArrival,
      );

      plannedStops.add(PlannedStop(station: chosen, departPercent: depart));
    }

    return RoutePlanResult(
      ok: true,
      totalDistanceKm: totalKm,
      requestedStops: stopsRequested,
      requiredStopsMin: requiredMin,
      arrivalPercentTarget: arrivalPercentTarget,
      stops: plannedStops,
    );
  }
}
