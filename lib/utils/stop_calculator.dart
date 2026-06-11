class StopCalculationResult {
  final bool isPossible;
  final String message;
  final double requiredRangePerLegKm;

  StopCalculationResult({
    required this.isPossible,
    required this.message,
    required this.requiredRangePerLegKm,
  });
}

class StopCalculator {
  static StopCalculationResult calculate({
    required double totalDistanceKm,
    required double usableRangeKm,
    required int stops,
    required double arrivalPercent,
  }) {
    // Kaç parça yol var?
    // 0 stop = 1 leg
    // 2 stop = 3 leg
    final int legs = stops + 1;

    // Varışta istenen batarya yüzdesi → efektif menzil düşer
    final double arrivalFactor = 1 - (arrivalPercent / 100);
    final double effectiveRangeKm = usableRangeKm * arrivalFactor;

    // Her bir parça kaç km?
    final double requiredRangePerLeg = totalDistanceKm / legs;

    if (requiredRangePerLeg > effectiveRangeKm) {
      return StopCalculationResult(
        isPossible: false,
        requiredRangePerLegKm: requiredRangePerLeg,
        message:
            "Not possible.\n\n"
            "Each leg would require ~${requiredRangePerLeg.toStringAsFixed(0)} km, "
            "but your effective range is ~${effectiveRangeKm.toStringAsFixed(0)} km.\n\n"
            "Increase stops or reduce arrival battery.",
      );
    }

    return StopCalculationResult(
      isPossible: true,
      requiredRangePerLegKm: requiredRangePerLeg,
      message:
          "Route is possible ✅\n\n"
          "Total distance: ${totalDistanceKm.toStringAsFixed(0)} km\n"
          "Stops: $stops\n"
          "Arrival battery: ${arrivalPercent.round()}%\n\n"
          "You should stop roughly every "
          "${requiredRangePerLeg.toStringAsFixed(0)} km.",
    );
  }
}
