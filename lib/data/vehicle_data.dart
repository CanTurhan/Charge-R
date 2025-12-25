import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/vehicle_model.dart';

class VehicleData {
  VehicleData._();

  static List<VehicleModel> _vehicles = [];

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/vehicles.json');
    final List decoded = jsonDecode(raw);
    _vehicles = decoded.map((e) => VehicleModel.fromJson(e)).toList();
  }

  // ✅ EKLENDİ: CalculateView / Preferences için tüm liste erişimi
  static List<VehicleModel> get vehicles => _vehicles;

  static List<String> get brands =>
      _vehicles.map((v) => v.brand).toSet().toList()..sort();

  static List<String> modelsByBrand(String brand) =>
      _vehicles
          .where((v) => v.brand == brand)
          .map((v) => v.model)
          .toSet()
          .toList()
        ..sort();

  static List<VehicleModel> versions({
    required String brand,
    required String model,
  }) {
    return _vehicles.where((v) => v.brand == brand && v.model == model).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
  }
}
