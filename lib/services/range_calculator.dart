import '../models/vehicle_model.dart';
import '../models/drive_enums.dart';

class RangeCalculator {
  static double calculate({
    required VehicleModel vehicle,
    required double speed,
    required DriveMode mode,
    required bool climateOn,
    required double chargePercent,
    required double temperature,
    required double climatePowerFactor,
    double degradationFactor = 1.0,
  }) {
    final usableEnergy =
        vehicle.batteryCapacity * degradationFactor * (chargePercent / 100);

    final speedFactor = _speedFactor(speed);
    final modeFactor = _modeFactor(mode);
    final tempFactor = _temperatureFactor(temperature);
    final climateFactor = climateOn ? climatePowerFactor : 1.0;

    final effectiveConsumption =
        vehicle.baseConsumption *
        speedFactor *
        modeFactor *
        tempFactor *
        climateFactor;

    return (usableEnergy / effectiveConsumption) * 100;
  }

  static double _speedFactor(double speed) {
    if (speed <= 90) return 1.0;
    if (speed <= 110) return 1.1;
    return 1.25;
  }

  static double _modeFactor(DriveMode mode) {
    switch (mode) {
      case DriveMode.eco:
        return 0.9;
      case DriveMode.normal:
        return 1.0;
      case DriveMode.sport:
        return 1.15;
    }
  }

  static double _temperatureFactor(double temp) {
    if (temp <= 0) return 1.25;
    if (temp <= 10) return 1.15;
    if (temp <= 30) return 1.0;
    if (temp <= 40) return 1.1;
    return 1.2;
  }
}
