class VehicleModel {
  final String brand;
  final String model;
  final String version; // SR, LR, AWD, etc.
  final double batteryCapacity; // kWh
  final double baseConsumption; // kWh / 100 km

  const VehicleModel({
    required this.brand,
    required this.model,
    required this.version,
    required this.batteryCapacity,
    required this.baseConsumption,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      brand: json['brand'],
      model: json['model'],
      version: json['version'],
      batteryCapacity: (json['battery_kwh'] as num).toDouble(),
      baseConsumption: (json['consumption_kwh_100km'] as num).toDouble(),
    );
  }
}
