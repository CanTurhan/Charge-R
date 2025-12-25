import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_vehicle_profile.dart';
import '../models/vehicle_model.dart';

class UserPreferences {
  static const _brandKey = "vehicle_brand";
  static const _modelKey = "vehicle_model";
  static const _versionKey = "vehicle_version";
  static const _yearKey = "vehicle_year";
  static const _kmKey = "vehicle_km";

  static Future<void> saveVehicleProfile({
    required VehicleModel vehicle,
    required int year,
    required int km,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_brandKey, vehicle.brand);
    await prefs.setString(_modelKey, vehicle.model);
    await prefs.setString(_versionKey, vehicle.version);
    await prefs.setInt(_yearKey, year);
    await prefs.setInt(_kmKey, km);
  }

  static Future<UserVehicleProfile?> loadVehicleProfile(
    List<VehicleModel> allVehicles,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final brand = prefs.getString(_brandKey);
    final model = prefs.getString(_modelKey);
    final version = prefs.getString(_versionKey);
    final year = prefs.getInt(_yearKey);
    final km = prefs.getInt(_kmKey);

    if (brand == null ||
        model == null ||
        version == null ||
        year == null ||
        km == null) {
      return null;
    }

    final vehicle = allVehicles.firstWhere(
      (v) => v.brand == brand && v.model == model && v.version == version,
    );

    return UserVehicleProfile(
      vehicle: vehicle,
      vehicleYear: year,
      mileageKm: km,
    );
  }
}
