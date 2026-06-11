class VehicleProfile {
  final double maxRangeKm; // %100 menzil
  final double usableRangeRatio; // %90 vs

  VehicleProfile({required this.maxRangeKm, required this.usableRangeRatio});

  double get usableRangeKm => maxRangeKm * usableRangeRatio;
}
