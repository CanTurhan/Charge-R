import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data/vehicle_data.dart';
import '../models/vehicle_model.dart';
import '../models/user_vehicle_profile.dart';
import '../services/user_preferences.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String? selectedBrand;
  String? selectedModel;
  VehicleModel? selectedVehicle;

  int? selectedYear;
  final kmController = TextEditingController();

  UserVehicleProfile? previewProfile;
  final int currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // -------- BUILD ALL VEHICLES (FIX) --------
  List<VehicleModel> _buildAllVehicles() {
    final List<VehicleModel> vehicles = [];

    for (final brand in VehicleData.brands) {
      final models = VehicleData.modelsByBrand(brand);
      for (final model in models) {
        vehicles.addAll(VehicleData.versions(brand: brand, model: model));
      }
    }
    return vehicles;
  }

  // -------- LOAD SAVED PROFILE --------
  Future<void> _loadProfile() async {
    final allVehicles = _buildAllVehicles();
    final saved = await UserPreferences.loadVehicleProfile(allVehicles);

    if (saved == null) return;

    setState(() {
      selectedBrand = saved.vehicle.brand;
      selectedModel = saved.vehicle.model;
      selectedVehicle = saved.vehicle;
      selectedYear = saved.vehicleYear;
      kmController.text = saved.mileageKm.toString();
      previewProfile = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Vehicle Profile", style: AppTextStyles.headline),
          const SizedBox(height: 24),

          // BRAND
          DropdownButtonFormField<String>(
            initialValue: selectedBrand,
            hint: const Text("Brand"),
            items: VehicleData.brands
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedBrand = v;
                selectedModel = null;
                selectedVehicle = null;
                previewProfile = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // MODEL
          DropdownButtonFormField<String>(
            initialValue: selectedModel,
            hint: const Text("Model"),
            items: selectedBrand == null
                ? []
                : VehicleData.modelsByBrand(selectedBrand!)
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
            onChanged: (v) {
              setState(() {
                selectedModel = v;
                selectedVehicle = null;
                previewProfile = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // VERSION
          DropdownButtonFormField<VehicleModel>(
            initialValue: selectedVehicle,
            hint: const Text("Version"),
            items: (selectedBrand == null || selectedModel == null)
                ? []
                : VehicleData.versions(
                        brand: selectedBrand!,
                        model: selectedModel!,
                      )
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text(v.version)),
                      )
                      .toList(),
            onChanged: (v) {
              setState(() {
                selectedVehicle = v;
                _updatePreview();
              });
            },
          ),
          const SizedBox(height: 16),

          // YEAR PICKER
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _openYearPicker();
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: "Vehicle year"),
              child: Text(
                selectedYear?.toString() ?? "Select year",
                style: AppTextStyles.body,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // KM
          TextField(
            controller: kmController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Mileage (km)"),
            onChanged: (_) => _updatePreview(),
          ),
          const SizedBox(height: 24),

          if (previewProfile != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                "Estimated battery health: "
                "${previewProfile!.batteryHealthPercent.toStringAsFixed(0)}%",
                style: AppTextStyles.title,
              ),
            ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed:
                selectedVehicle == null ||
                    selectedYear == null ||
                    kmController.text.isEmpty
                ? null
                : () async {
                    final km = int.tryParse(kmController.text);
                    if (km == null) return;

                    await UserPreferences.saveVehicleProfile(
                      vehicle: selectedVehicle!,
                      year: selectedYear!,
                      km: km,
                    );

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Vehicle profile saved")),
                    );
                  },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _updatePreview() {
    final km = int.tryParse(kmController.text);
    if (selectedVehicle == null || selectedYear == null || km == null) {
      setState(() => previewProfile = null);
      return;
    }

    setState(() {
      previewProfile = UserVehicleProfile(
        vehicle: selectedVehicle!,
        vehicleYear: selectedYear!,
        mileageKm: km,
      );
    });
  }

  // -------- YEAR PICKER (scale + opacity + haptic) --------
  void _openYearPicker() {
    final years = List.generate(currentYear - 1980 + 1, (i) => currentYear - i);

    int tempIndex = selectedYear == null ? 0 : years.indexOf(selectedYear!);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) {
        return SizedBox(
          height: 300,
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(
              initialItem: tempIndex,
            ),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() {
                selectedYear = years[i];
                _updatePreview();
              });
            },
            children: List.generate(years.length, (i) {
              final selected = i == tempIndex;
              return AnimatedOpacity(
                opacity: selected ? 1 : 0.4,
                duration: const Duration(milliseconds: 150),
                child: AnimatedScale(
                  scale: selected ? 1.15 : 0.9,
                  duration: const Duration(milliseconds: 150),
                  child: Center(
                    child: Text(
                      years[i].toString(),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
