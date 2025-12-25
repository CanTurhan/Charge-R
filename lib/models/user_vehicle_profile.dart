import 'vehicle_model.dart';

class UserVehicleProfile {
  final VehicleModel vehicle;
  final int vehicleYear;
  final int mileageKm;

  const UserVehicleProfile({
    required this.vehicle,
    required this.vehicleYear,
    required this.mileageKm,
  });

  double get degradationFactor {
    final age = DateTime.now().year - vehicleYear;
    final ageLoss = age * 0.015;
    final mileageLoss = (mileageKm / 20000) * 0.01;

    final factor = 1.0 - (ageLoss + mileageLoss);
    return factor.clamp(0.70, 1.0);
  }

  double get batteryHealthPercent => degradationFactor * 100;
}
