import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OcmStation {
  final int id;
  final String title;
  final LatLng point;

  OcmStation({required this.id, required this.title, required this.point});

  factory OcmStation.fromJson(Map<String, dynamic> json) {
    final addr = json['AddressInfo'];

    return OcmStation(
      id: json['ID'] ?? 0,
      title: addr?['Title'] ?? 'Charging Station',
      point: LatLng(
        ((addr?['Latitude'] ?? 0) as num).toDouble(),
        ((addr?['Longitude'] ?? 0) as num).toDouble(),
      ),
    );
  }
}

class OpenChargeMapService {
  static const String _baseUrl = 'https://api.openchargemap.io/v3/poi';
  static const String _apiKey = '2cc876c2-52a7-42a3-ac65-7230575d189b';

  static Future<List<OcmStation>> fetchNearby({
    required double lat,
    required double lng,
    double distanceKm = 20,
    int maxResults = 50,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'output': 'json',
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'distance': distanceKm.toString(),
        'distanceunit': 'KM',
        'maxresults': maxResults.toString(),
        'compact': 'false',
        'verbose': 'false',
        'statusid': '50',
      },
    );

    final res = await http.get(
      uri,
      headers: {'X-API-Key': _apiKey, 'User-Agent': 'Charge-R Flutter App'},
    );

    if (res.statusCode != 200) {
      throw Exception('OCM HTTP ${res.statusCode}');
    }

    final List data = jsonDecode(res.body);

    return data
        .map((e) => OcmStation.fromJson(e))
        .where(
          (s) =>
              s.point.latitude != 0 &&
              s.point.longitude != 0 &&
              s.title.isNotEmpty,
        )
        .toList();
  }

  static Future<OcmStation?> findClosestStation({
    required double lat,
    required double lng,
  }) async {
    final list = await fetchNearby(
      lat: lat,
      lng: lng,
      distanceKm: 30,
      maxResults: 1,
    );

    if (list.isEmpty) return null;
    return list.first;
  }
}
