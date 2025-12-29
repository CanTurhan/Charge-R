import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String displayName;
  final LatLng point;

  PlaceSuggestion({required this.displayName, required this.point});
}

class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  static const _headers = {
    'User-Agent': 'Charge-R/1.0 (contact@charger.app)',
    'Accept': 'application/json',
  };

  static Future<List<PlaceSuggestion>> searchSuggestions(
    String query, {
    int limit = 6,
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': limit.toString(),
      },
    );

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];

    final List data = jsonDecode(res.body);
    return data.map((e) {
      return PlaceSuggestion(
        displayName: e['display_name'],
        point: LatLng(double.parse(e['lat']), double.parse(e['lon'])),
      );
    }).toList();
  }

  static Future<LatLng?> addressToLatLng(String address) async {
    final list = await searchSuggestions(address, limit: 1);
    return list.isEmpty ? null : list.first.point;
  }

  static Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(
      queryParameters: {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
      },
    );

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    return data['display_name'];
  }
}
