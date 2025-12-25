import 'package:flutter/material.dart';
import '../data/vehicle_data.dart';
import '../models/vehicle_model.dart';
import '../models/drive_enums.dart';
import '../models/climate_enums.dart';
import '../models/user_vehicle_profile.dart';
import '../services/user_preferences.dart';
import '../services/range_calculator.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class CalculateView extends StatefulWidget {
  const CalculateView({super.key});

  @override
  State<CalculateView> createState() => _CalculateViewState();
}

class _CalculateViewState extends State<CalculateView> {
  late final Future<void> _loadVehiclesFuture;

  String? selectedBrand;
  String? selectedModelName;
  VehicleModel? selectedVersion;

  UserVehicleProfile? profileVehicle;

  String modelSearchQuery = "";
  String versionSearchQuery = "";

  double speed = 90;
  double charge = 80;
  double temperature = 20;

  DriveMode driveMode = DriveMode.normal;
  ClimatePower climatePower = ClimatePower.medium;
  bool climateOn = false;

  double? resultKm;

  @override
  void initState() {
    super.initState();
    _loadVehiclesFuture = VehicleData.load().then((_) async {
      final p = await UserPreferences.loadVehicleProfile(VehicleData.vehicles);
      if (mounted) setState(() => profileVehicle = p);
    });
  }

  double _climateFactor() {
    switch (climatePower) {
      case ClimatePower.low:
        return 1.05;
      case ClimatePower.medium:
        return 1.1;
      case ClimatePower.high:
        return 1.2;
    }
  }

  VehicleModel? get _activeVehicle =>
      selectedVersion ?? profileVehicle?.vehicle;

  double get _activeDegradationFactor =>
      profileVehicle?.degradationFactor ?? 1.0;

  void _calculate() {
    final vehicle = _activeVehicle;
    if (vehicle == null) return;

    final km = RangeCalculator.calculate(
      vehicle: vehicle,
      speed: speed,
      mode: driveMode,
      climateOn: climateOn,
      chargePercent: charge,
      temperature: temperature,
      climatePowerFactor: _climateFactor(),
      degradationFactor: _activeDegradationFactor,
    );

    setState(() => resultKm = km);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadVehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SafeArea(
            child: Center(
              child: Text(
                "Failed to load vehicles",
                style: AppTextStyles.title,
              ),
            ),
          );
        }

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- HEADER WITH LOGO ----------
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/app_icon.png",
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text("Calculate Range", style: AppTextStyles.headline),
                ],
              ),
              const SizedBox(height: 16),

              _profileBadge(),
              const SizedBox(height: 16),

              _vehicleSection(),
              const SizedBox(height: 16),

              _usageSection(),
              const SizedBox(height: 16),

              _batterySection(),
              const SizedBox(height: 16),

              _environmentSection(),
              const SizedBox(height: 24),

              _resultCard(),
            ],
          ),
        );
      },
    );
  }

  // ---------------- PROFILE BADGE ----------------

  Widget _profileBadge() {
    if (profileVehicle == null) {
      return _infoBox(
        icon: Icons.info_outline,
        text: "No profile vehicle set. You can still calculate manually.",
      );
    }

    final v = profileVehicle!.vehicle;
    final health = profileVehicle!.batteryHealthPercent.toStringAsFixed(0);

    return _infoBox(
      icon: Icons.verified,
      title: "Using profile vehicle",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${v.brand} ${v.model} • ${v.version} (${v.batteryCapacity.toStringAsFixed(1)} kWh)",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 4),
          Text("Battery health: $health%", style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _infoBox({
    required IconData icon,
    String? title,
    String? text,
    Widget? content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title, style: AppTextStyles.title),
                if (title != null) const SizedBox(height: 6),
                if (text != null) Text(text, style: AppTextStyles.body),
                if (content != null) content,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- VEHICLE ----------------

  Widget _vehicleSection() {
    return _card(
      title: "Manual Vehicle Override (optional)",
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedBrand,
            hint: const Text("Brand"),
            items: VehicleData.brands
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedBrand = v;
                selectedModelName = null;
                selectedVersion = null;
                resultKm = null;
              });
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: selectedBrand == null ? null : _openModelPicker,
            child: _pickerField(text: selectedModelName ?? "Select Model"),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: (selectedBrand == null || selectedModelName == null)
                ? null
                : _openVersionPicker,
            child: _pickerField(
              text: selectedVersion == null
                  ? "Select Version"
                  : "${selectedVersion!.version} (${selectedVersion!.batteryCapacity.toStringAsFixed(1)} kWh)",
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedBrand = null;
                      selectedModelName = null;
                      selectedVersion = null;
                      resultKm = null;
                    });
                    _calculate();
                  },
                  child: const Text("Use Profile Vehicle"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: selectedVersion == null ? null : _calculate,
                  child: const Text("Calculate"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- USAGE ----------------

  Widget _usageSection() {
    return _card(
      title: "Driving",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Speed: ${speed.round()} km/h"),
          Slider(
            value: speed,
            min: 60,
            max: 150,
            divisions: 9,
            onChanged: (v) {
              setState(() => speed = v);
              _calculate();
            },
          ),
          Wrap(
            spacing: 8,
            children: DriveMode.values.map((m) {
              return ChoiceChip(
                label: Text(m.name.toUpperCase()),
                selected: driveMode == m,
                onSelected: (_) {
                  setState(() => driveMode = m);
                  _calculate();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------- BATTERY ----------------

  Widget _batterySection() {
    return _card(
      title: "Battery",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Charge: ${charge.round()}%"),
          Slider(
            value: charge,
            min: 5,
            max: 100,
            divisions: 19,
            onChanged: (v) {
              setState(() => charge = v);
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  // ---------------- ENVIRONMENT ----------------

  Widget _environmentSection() {
    return _card(
      title: "Environment",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Outside temperature: ${temperature.round()}°C"),
          Slider(
            value: temperature,
            min: -10,
            max: 45,
            divisions: 11,
            onChanged: (v) {
              setState(() => temperature = v);
              _calculate();
            },
          ),
          SwitchListTile(
            title: const Text("Climate On"),
            value: climateOn,
            onChanged: (v) {
              setState(() => climateOn = v);
              _calculate();
            },
          ),
          if (climateOn)
            Wrap(
              spacing: 8,
              children: ClimatePower.values.map((c) {
                return ChoiceChip(
                  label: Text(c.name.toUpperCase()),
                  selected: climatePower == c,
                  onSelected: (_) {
                    setState(() => climatePower = c);
                    _calculate();
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ---------------- RESULT ----------------

  Widget _resultCard() {
    final vehicle = _activeVehicle;

    return _card(
      title: "Result",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicle == null
                ? "Select a vehicle (profile or manual) to calculate"
                : "${resultKm?.toStringAsFixed(0) ?? "--"} km",
            style: AppTextStyles.title,
          ),
          if (vehicle != null) ...[
            const SizedBox(height: 10),
            Text(
              "Vehicle: ${vehicle.brand} ${vehicle.model} • ${vehicle.version}",
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 4),
            Text(
              "Applied battery health: ${(100 * _activeDegradationFactor).toStringAsFixed(0)}%",
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- PICKERS ----------------

  void _openModelPicker() {
    if (selectedBrand == null) return;

    final models = VehicleData.modelsByBrand(selectedBrand!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = models
                .where(
                  (m) =>
                      m.toLowerCase().contains(modelSearchQuery.toLowerCase()),
                )
                .toList();

            return _pickerSheet(
              hint: "Search model",
              onChanged: (v) => setSheetState(() => modelSearchQuery = v),
              items: filtered.map((m) {
                return ListTile(
                  title: Text(m),
                  onTap: () {
                    setState(() {
                      selectedModelName = m;
                      selectedVersion = null;
                      modelSearchQuery = "";
                      resultKm = null;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _openVersionPicker() {
    if (selectedBrand == null || selectedModelName == null) return;

    final versions = VehicleData.versions(
      brand: selectedBrand!,
      model: selectedModelName!,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = versionSearchQuery.toLowerCase();
            final filtered = versions.where((v) {
              return v.version.toLowerCase().contains(q) ||
                  v.batteryCapacity.toString().contains(q);
            }).toList();

            return _pickerSheet(
              hint: "Search version",
              onChanged: (v) => setSheetState(() => versionSearchQuery = v),
              items: filtered.map((v) {
                return ListTile(
                  title: Text(v.version),
                  subtitle: Text("${v.batteryCapacity.toStringAsFixed(1)} kWh"),
                  onTap: () {
                    setState(() {
                      selectedVersion = v;
                      versionSearchQuery = "";
                      resultKm = null;
                    });
                    Navigator.pop(context);
                    _calculate();
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _pickerField({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(text, style: AppTextStyles.body)),
          const Icon(Icons.search),
        ],
      ),
    );
  }

  Widget _pickerSheet({
    required String hint,
    required ValueChanged<String> onChanged,
    required List<Widget> items,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(height: 320, child: ListView(children: items)),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
