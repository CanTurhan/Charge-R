import 'package:flutter/material.dart';
import '../data/vehicle_data.dart';
import '../models/vehicle_model.dart';
import '../models/user_vehicle_profile.dart';
import '../services/user_preferences.dart';
import '../theme/text_styles.dart';
import '../theme/colors.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String? selectedBrand;
  String? selectedModel;
  VehicleModel? selectedVersion;

  int? selectedYear;
  final kmController = TextEditingController();

  UserVehicleProfile? previewProfile;

  final int currentYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- HEADER ----------
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _openPrivacySettings,
              ),
              const SizedBox(width: 8),
              Text("Vehicle Profile", style: AppTextStyles.headline),
            ],
          ),
          const SizedBox(height: 24),

          // ---------- BRAND ----------
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
                selectedVersion = null;
                selectedYear = null;
                previewProfile = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // ---------- MODEL ----------
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
                selectedVersion = null;
                previewProfile = null;
              });
            },
          ),
          const SizedBox(height: 12),

          // ---------- VERSION ----------
          DropdownButtonFormField<VehicleModel>(
            initialValue: selectedVersion,
            hint: const Text("Version / Battery"),
            items: (selectedBrand == null || selectedModel == null)
                ? []
                : VehicleData.versions(
                        brand: selectedBrand!,
                        model: selectedModel!,
                      )
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            "${v.version} (${v.batteryCapacity.toStringAsFixed(1)} kWh)",
                          ),
                        ),
                      )
                      .toList(),
            onChanged: (v) {
              setState(() {
                selectedVersion = v;
                _updatePreview();
              });
            },
          ),
          const SizedBox(height: 16),

          // ---------- YEAR (DROPDOWN) ----------
          DropdownButtonFormField<int>(
            initialValue: selectedYear,
            hint: const Text("Vehicle year"),
            items: List.generate(currentYear - 1980 + 1, (index) {
              final year = currentYear - index;
              return DropdownMenuItem(
                value: year,
                child: Text(year.toString()),
              );
            }),
            onChanged: (v) {
              setState(() {
                selectedYear = v;
                _updatePreview();
              });
            },
          ),
          const SizedBox(height: 12),

          // ---------- KM ----------
          TextField(
            controller: kmController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: "Mileage (km)"),
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
            onChanged: (_) => _updatePreview(),
          ),
          const SizedBox(height: 24),

          // ---------- PREVIEW ----------
          if (previewProfile != null)
            Container(
              padding: const EdgeInsets.all(14),
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

          // ---------- SAVE ----------
          ElevatedButton(
            onPressed:
                selectedVersion == null ||
                    selectedYear == null ||
                    kmController.text.isEmpty
                ? null
                : () async {
                    FocusScope.of(context).unfocus();

                    final km = int.tryParse(kmController.text);
                    if (km == null) return;

                    await UserPreferences.saveVehicleProfile(
                      vehicle: selectedVersion!,
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

  // ---------- PREVIEW LOGIC ----------
  void _updatePreview() {
    final km = int.tryParse(kmController.text);

    if (selectedVersion == null || selectedYear == null || km == null) {
      setState(() => previewProfile = null);
      return;
    }

    setState(() {
      previewProfile = UserVehicleProfile(
        vehicle: selectedVersion!,
        vehicleYear: selectedYear!,
        mileageKm: km,
      );
    });
  }

  // ---------- PRIVACY ----------
  void _openPrivacySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Privacy Settings", style: AppTextStyles.title),
              SizedBox(height: 12),
              Text(
                "Charge-R does not collect, store, or transmit any personal data.\n\n"
                "All vehicle information is stored locally on your device.\n\n"
                "No analytics, tracking, or third-party sharing is used.",
                style: AppTextStyles.body,
              ),
            ],
          ),
        );
      },
    );
  }
}
