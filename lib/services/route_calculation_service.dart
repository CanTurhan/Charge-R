class RouteCalcInput {
  final double totalKm; // rota toplam km
  final double batteryKwh; // batarya kapasitesi
  final double consumptionKwhPer100km; // ortalama tüketim
  final int desiredStops; // kullanıcı kaç kere durmak istiyor
  final double arrivalSoC; // varışta istenen min batarya (0.40 gibi)

  const RouteCalcInput({
    required this.totalKm,
    required this.batteryKwh,
    required this.consumptionKwhPer100km,
    required this.desiredStops,
    required this.arrivalSoC,
  });
}

class RouteCalcResult {
  final bool feasible;
  final int minStopsRequired;
  final double maxSegmentKm; // tek şarj arası maksimum km
  final double segmentKmForDesiredStops;
  final String message;

  const RouteCalcResult({
    required this.feasible,
    required this.minStopsRequired,
    required this.maxSegmentKm,
    required this.segmentKmForDesiredStops,
    required this.message,
  });
}

class RouteCalculationService {
  /// Basit model:
  /// - Kullanılabilir enerji = batteryKwh * (1 - arrivalSoC)
  /// - Max segment km = (usableKwh / consumption) * 100
  /// - desiredStops -> segments = stops + 1
  /// - Segment km = totalKm / segments
  static RouteCalcResult calculate(RouteCalcInput input) {
    final arrival = input.arrivalSoC.clamp(0.0, 0.95);
    final usableKwh = input.batteryKwh * (1.0 - arrival);

    if (usableKwh <= 0) {
      return const RouteCalcResult(
        feasible: false,
        minStopsRequired: 0,
        maxSegmentKm: 0,
        segmentKmForDesiredStops: 0,
        message: "Arrival battery is too high. Reduce arrival percentage.",
      );
    }

    final maxSegmentKm = (usableKwh / input.consumptionKwhPer100km) * 100.0;

    final desiredSegments = input.desiredStops + 1;
    final segmentKm = input.totalKm / desiredSegments;

    // minimum stops: find smallest stops such that totalKm/(stops+1) <= maxSegmentKm
    int minStops = 0;
    while (minStops < 20) {
      final seg = input.totalKm / (minStops + 1);
      if (seg <= maxSegmentKm) break;
      minStops++;
    }

    final feasible = segmentKm <= maxSegmentKm;

    final message = feasible
        ? "Possible with ${input.desiredStops} stop(s)."
        : "Not possible with ${input.desiredStops} stop(s). Minimum stops: $minStops.";

    return RouteCalcResult(
      feasible: feasible,
      minStopsRequired: minStops,
      maxSegmentKm: maxSegmentKm,
      segmentKmForDesiredStops: segmentKm,
      message: message,
    );
  }
}
