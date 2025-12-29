import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String displayName;
  final LatLng point;

  const PlaceSuggestion({required this.displayName, required this.point});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      displayName: (json['display_name'] ?? '').toString(),
      point: LatLng(
        double.parse(json['lat'].toString()),
        double.parse(json['lon'].toString()),
      ),
    );
  }
}

class GeocodingService {
  static const String _base = 'https://nominatim.openstreetmap.org';

  static Map<String, String> _headers() => {
    // Nominatim tarafında User-Agent şart.
    'User-Agent': 'Charge-R Flutter App',
    'Accept': 'application/json',
  };

  /// Autocomplete suggestions (Kadıköy, Çankaya, Amsterdam vs.)
  static Future<List<PlaceSuggestion>> searchSuggestions(
    String query, {
    int limit = 6,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'q': q,
        'format': 'json',
        'addressdetails': '1',
        'limit': limit.toString(),
      },
    );

    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) return [];

    final List data = jsonDecode(res.body);
    return data.map((e) => PlaceSuggestion.fromJson(e)).toList();
  }

  /// String address -> LatLng (first match)
  static Future<LatLng?> addressToLatLng(String address) async {
    final list = await searchSuggestions(address, limit: 1);
    if (list.isEmpty) return null;
    return list.first.point;
  }

  /// LatLng -> readable name (for Start default text)
  static Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {
        'format': 'json',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'zoom': '16',
      },
    );

    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) return null;

    final Map data = jsonDecode(res.body);
    return (data['display_name'] ?? '').toString().trim().isEmpty
        ? null
        : data['display_name'].toString();
  }
}
