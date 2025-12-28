import 'package:latlong2/latlong.dart';

class ChargingStation {
  final int id;
  final String title;
  final LatLng position;

  ChargingStation({
    required this.id,
    required this.title,
    required this.position,
  });

  factory ChargingStation.fromOcmJson(Map<String, dynamic> json) {
    final address = json['AddressInfo'];

    return ChargingStation(
      id: json['ID'],
      title: address?['Title'] ?? 'Charging Station',
      position: LatLng(address['Latitude'], address['Longitude']),
    );
  }
}
